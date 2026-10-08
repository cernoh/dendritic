/*
 * ghostty-term — PTY-backed terminal emulator for the Noctalia terminal plugin.
 *
 * The plugin runs in a Luau sandbox with no foreign function interface, so it
 * cannot call libghostty-vt directly. This helper owns the pseudo-terminal and
 * the libghostty-vt terminal state, then bridges both sides:
 *
 *   stdout  one JSON frame per line, each frame describing the visible screen
 *   FIFO    one command per line, read from the path in argv[1]
 *
 * Commands
 *   i<escaped text>   write text to the shell (escapes: \n \r \t \e \\)
 *   k<key name>       send an encoded key (up, ctrl+c, tab, backspace, ...)
 *   p<fg>,<bg>,<256 colors>
 *                     set the default colors and the 256-color palette
 *   s<n>              scroll the viewport by n rows (negative scrolls up)
 *   z<COLS>x<ROWS>    resize the terminal and the pseudo-terminal
 *   f                 emit a frame now
 *   q                 quit
 *
 * Usage: ghostty-term <fifo-path> <cols> <rows> [shell]
 *
 * Frames carry only what the Noctalia panel can draw: a foreground color and a
 * bold flag per text run. The panel API has no per-cell background and no
 * canvas, so backgrounds, italics, and underlines are not transmitted.
 */

#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pty.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#include <ghostty/vt.h>

/* Minimum delay between two frames. A build log dirties the screen on every
 * write, and the plugin re-renders its whole tree per frame. */
#define FRAME_MIN_MS 80L

/* Bounded so one pathological row cannot produce an unbounded frame. */
#define MAX_GRAPHEME_BYTES 64
#define MAX_RUN_BYTES 8192
#define MAX_RUNS_PER_ROW 96
#define MAX_FRAME_BYTES (256 * 1024)

typedef struct {
  char *p;
  size_t len;
  size_t cap;
} Buf;

static bool buf_reserve(Buf *b, size_t extra) {
  if (b->len + extra + 1 <= b->cap) return true;
  size_t cap = b->cap ? b->cap : 4096;
  while (cap < b->len + extra + 1) cap *= 2;
  char *p = realloc(b->p, cap);
  if (p == NULL) return false;
  b->p = p;
  b->cap = cap;
  return true;
}

static void buf_put(Buf *b, const char *s, size_t n) {
  if (!buf_reserve(b, n)) return;
  memcpy(b->p + b->len, s, n);
  b->len += n;
  b->p[b->len] = '\0';
}

static void buf_puts(Buf *b, const char *s) { buf_put(b, s, strlen(s)); }

static void json_escape(Buf *b, unsigned char c) {
  switch (c) {
    case '"': buf_puts(b, "\\\""); break;
    case '\\': buf_puts(b, "\\\\"); break;
    case '\n': buf_puts(b, "\\n"); break;
    case '\r': buf_puts(b, "\\r"); break;
    case '\t': buf_puts(b, "\\t"); break;
    default:
      if (c < 0x20) {
        char tmp[8];
        snprintf(tmp, sizeof(tmp), "\\u%04x", c);
        buf_puts(b, tmp);
      } else {
        buf_put(b, (const char *)&c, 1);
      }
  }
}

static void json_string(Buf *b, const char *s, size_t n) {
  buf_put(b, "\"", 1);
  for (size_t i = 0; i < n; i++) json_escape(b, (unsigned char)s[i]);
  buf_put(b, "\"", 1);
}

static void rgb_hex(GhosttyColorRgb c, char out[8]) {
  snprintf(out, 8, "#%02x%02x%02x", c.r, c.g, c.b);
}

static long now_ms(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (long)ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

/* ------------------------------------------------------------------ */

typedef struct {
  GhosttyTerminal term;
  GhosttyKeyEncoder enc;
  GhosttyMouseEncoder mouse;
  /* A second encoder answers "is the app listening for the mouse?" without
   * disturbing the real one's motion-dedup state. */
  GhosttyMouseEncoder probe;
  uint16_t cols;
  uint16_t rows;
  int master;
  /* Cell size in surface pixels, sent by the panel as "g<w>x<h>". The mouse
   * encoder takes pixels, and the plugin is the only side that knows how wide
   * it drew a cell. */
  double cell_w;
  double cell_h;
  unsigned long seq;
} Term;

/* Forward declarations: emit_frame reports whether the app wants the mouse, and
 * the mouse helpers sit below it next to send_key. */
static bool mouse_reporting(Term *t);

typedef struct {
  char text[MAX_RUN_BYTES];
  size_t len;
  char fg[8];
  bool bold;
} Run;

/* Emit the finished run, then start a new one. Trailing spaces never end a run:
 * they move to the next run, so a renderer that trims them cannot shift the
 * runs after it. */
static void flush_run(Buf *out, Run *run, bool *open, size_t *carried,
                      unsigned *runs, const char *default_fg) {
  while (run->len > 0 && run->text[run->len - 1] == ' ') {
    run->len--;
    (*carried)++;
  }
  if (*open && run->len > 0 && *runs < MAX_RUNS_PER_ROW) {
    if (*runs > 0) buf_puts(out, ",");
    buf_puts(out, "{\"t\":");
    json_string(out, run->text, run->len);
    if (strcmp(run->fg, default_fg) != 0) {
      buf_puts(out, ",\"f\":");
      json_string(out, run->fg, strlen(run->fg));
    }
    if (run->bold) buf_puts(out, ",\"b\":true");
    buf_puts(out, "}");
    (*runs)++;
  }
  run->len = 0;
  *open = false;
}

static void emit_frame(Term *t, GhosttyRenderState st, bool force) {
  if (ghostty_render_state_update(st, t->term) != GHOSTTY_SUCCESS) return;

  GhosttyRenderStateDirty dirty = GHOSTTY_RENDER_STATE_DIRTY_FALSE;
  ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_DIRTY, &dirty);
  if (!force && dirty == GHOSTTY_RENDER_STATE_DIRTY_FALSE) return;

  GhosttyRenderStateColors colors = GHOSTTY_INIT_SIZED(GhosttyRenderStateColors);
  if (ghostty_render_state_colors_get(st, &colors) != GHOSTTY_SUCCESS) return;

  char default_fg[8];
  char default_bg[8];
  rgb_hex(colors.foreground, default_fg);
  rgb_hex(colors.background, default_bg);

  uint16_t cols = 0, rows = 0;
  ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_COLS, &cols);
  ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_ROWS, &rows);

  GhosttyRenderStateRowIterator it = NULL;
  GhosttyRenderStateRowCells cells = NULL;
  if (ghostty_render_state_row_iterator_new(NULL, &it) != GHOSTTY_SUCCESS) return;
  if (ghostty_render_state_row_cells_new(NULL, &cells) != GHOSTTY_SUCCESS) {
    ghostty_render_state_row_iterator_free(it);
    return;
  }
  if (ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR, &it) != GHOSTTY_SUCCESS) {
    ghostty_render_state_row_cells_free(cells);
    ghostty_render_state_row_iterator_free(it);
    return;
  }

  Buf out = {0};
  char head[224];
  snprintf(head, sizeof(head),
           "{\"t\":\"f\",\"s\":%lu,\"c\":%u,\"r\":%u,\"dfg\":\"%s\",\"dbg\":\"%s\",\"mouse\":%s,\"L\":[",
           ++t->seq, (unsigned)cols, (unsigned)rows, default_fg, default_bg,
           mouse_reporting(t) ? "true" : "false");
  buf_puts(&out, head);

  Run run;
  bool run_open = false;
  size_t carried = 0;
  unsigned runs = 0;
  bool stopped = false;

  for (uint16_t y = 0; y < rows; y++) {
    if (!ghostty_render_state_row_iterator_next(it)) {
      stopped = true;
      break;
    }
    if (y > 0) buf_puts(&out, ",");
    buf_puts(&out, "[");

    run.len = 0;
    run_open = false;
    carried = 0;
    runs = 0;

    if (ghostty_render_state_row_get(it, GHOSTTY_RENDER_STATE_ROW_DATA_CELLS, &cells) != GHOSTTY_SUCCESS) {
      buf_puts(&out, "]");
      continue;
    }

    bool overflow = false;
    while (ghostty_render_state_row_cells_next(cells)) {
      uint8_t gbuf[MAX_GRAPHEME_BYTES];
      GhosttyBuffer gb = {.ptr = gbuf, .cap = sizeof(gbuf)};
      GhosttyResult gr = ghostty_render_state_row_cells_get(
          cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_UTF8, &gb);
      bool has_text = (gr == GHOSTTY_SUCCESS && gb.len > 0);

      char cell_fg[8];
      bool cell_bold = false;
      bool cell_invisible = false;

      if (has_text) {
        GhosttyStyle style = GHOSTTY_INIT_SIZED(GhosttyStyle);
        if (ghostty_render_state_row_cells_get(
                cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE, &style) == GHOSTTY_SUCCESS) {
          cell_bold = style.bold;
          cell_invisible = style.invisible;
        }

        GhosttyColorRgb fg = colors.foreground;
        if (style.inverse) {
          /* No per-cell background is renderable, so an inverted cell shows the
           * color its background would have had. */
          GhosttyColorRgb bg = {0};
          if (ghostty_render_state_row_cells_get(
                  cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_BG_COLOR, &bg) == GHOSTTY_SUCCESS) {
            fg = bg;
          }
        } else {
          GhosttyColorRgb cell = {0};
          if (ghostty_render_state_row_cells_get(
                  cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_FG_COLOR, &cell) == GHOSTTY_SUCCESS) {
            fg = cell;
          }
        }
        rgb_hex(fg, cell_fg);
      } else {
        memcpy(cell_fg, default_fg, sizeof(cell_fg));
      }

      bool same = run_open && run.bold == cell_bold && strcmp(run.fg, cell_fg) == 0;
      if (!same) {
        flush_run(&out, &run, &run_open, &carried, &runs, default_fg);
        run_open = true;
        run.bold = cell_bold;
        memcpy(run.fg, cell_fg, sizeof(run.fg));
      }

      while (carried > 0 && run.len < MAX_RUN_BYTES - 1) {
        run.text[run.len++] = ' ';
        carried--;
      }

      if (cell_invisible) {
        for (size_t i = 0; i < gb.len && run.len < MAX_RUN_BYTES - 1; i++) run.text[run.len++] = ' ';
      } else if (has_text) {
        for (size_t i = 0; i < gb.len && run.len < MAX_RUN_BYTES - 1; i++) {
          run.text[run.len++] = (char)gbuf[i];
        }
      } else if (run.len < MAX_RUN_BYTES - 1) {
        run.text[run.len++] = ' ';
      }

      if (run.len >= MAX_RUN_BYTES - 1 || out.len > MAX_FRAME_BYTES) {
        overflow = true;
        break;
      }
    }

    /* Drop the final run's trailing spaces: nothing follows them on this row. */
    {
      size_t dropped = 0;
      flush_run(&out, &run, &run_open, &dropped, &runs, default_fg);
    }
    buf_puts(&out, "]");

    if (overflow) {
      for (uint16_t rest = y + 1; rest < rows; rest++) buf_puts(&out, ",[]");
      stopped = true;
      break;
    }
  }

  if (stopped && out.len > 0 && out.p[out.len - 1] == ']') {
    /* Either every row was emitted or the remaining rows were padded above. */
  }
  buf_puts(&out, "]}");
  buf_put(&out, "\n", 1);

  fwrite(out.p, 1, out.len, stdout);
  fflush(stdout);
  free(out.p);

  ghostty_render_state_row_cells_free(cells);
  ghostty_render_state_row_iterator_free(it);
}

/* ------------------------------------------------------------------ */

static size_t unescape(char *dst, size_t dst_cap, const char *src) {
  size_t n = 0;
  for (const char *p = src; *p && n + 1 < dst_cap; p++) {
    if (*p != '\\') {
      dst[n++] = *p;
      continue;
    }
    switch (p[1]) {
      case 'n': dst[n++] = '\n'; p++; break;
      case 'r': dst[n++] = '\r'; p++; break;
      case 't': dst[n++] = '\t'; p++; break;
      case 'e': dst[n++] = 0x1b; p++; break;
      case '\\': dst[n++] = '\\'; p++; break;
      case '\0': dst[n++] = '\\'; break;
      default: dst[n++] = p[1]; p++; break;
    }
  }
  dst[n] = '\0';
  return n;
}

static void write_all(int fd, const char *p, size_t n) {
  size_t off = 0;
  while (off < n) {
    ssize_t w = write(fd, p + off, n - off);
    if (w > 0) {
      off += (size_t)w;
    } else if (w < 0 && (errno == EINTR || errno == EAGAIN)) {
      continue;
    } else {
      return;
    }
  }
}

/* libghostty-vt parses a terminal's queries but does not answer them: an
 * embedder must. Without these two callbacks a program that waits for a reply
 * blocks: fish waits ten seconds on its startup Primary DA query and then warns
 * that it "could not read response to Primary Device Attribute query". The
 * device attributes callback fills the response data, and the library writes
 * the finished escape sequence back through the write_pty callback. */
static void on_write_pty(GhosttyTerminal term, void *userdata, const uint8_t *data, size_t len) {
  (void)term;
  write_all(*(int *)userdata, (const char *)data, len);
}

static bool on_device_attributes(GhosttyTerminal term, void *userdata, GhosttyDeviceAttributes *out) {
  (void)term;
  (void)userdata;
  memset(out, 0, sizeof(*out));

  /* VT220 with selective erase, national replacement, technical characters,
   * ANSI color and the ANSI text locator. 132-column mode is not claimed: this
   * terminal never acts on DECCOLM. */
  static const uint16_t features[] = {
      GHOSTTY_DA_FEATURE_SELECTIVE_ERASE,
      GHOSTTY_DA_FEATURE_NATIONAL_REPLACEMENT,
      GHOSTTY_DA_FEATURE_TECHNICAL_CHARACTERS,
      GHOSTTY_DA_FEATURE_ANSI_COLOR,
      GHOSTTY_DA_FEATURE_ANSI_TEXT_LOCATOR,
  };
  out->primary.conformance_level = GHOSTTY_DA_CONFORMANCE_VT220;
  memcpy(out->primary.features, features, sizeof(features));
  out->primary.num_features = sizeof(features) / sizeof(features[0]);

  out->secondary.device_type = GHOSTTY_DA_DEVICE_TYPE_VT220;
  out->secondary.firmware_version = 1;
  out->secondary.rom_cartridge = 0;
  out->tertiary.unit_id = 0;
  return true;
}

/* Mouse events are encoded by the library, which already knows the app's
 * tracking mode and output format, so the helper never writes SGR bytes by
 * hand. Coordinates arrive as cells and are scaled into the surface space the
 * encoder expects. */
static void set_mouse_geometry(Term *t) {
  if (t->cell_w <= 0 || t->cell_h <= 0) return;
  GhosttyMouseEncoderSize size = GHOSTTY_INIT_SIZED(GhosttyMouseEncoderSize);
  size.cell_width = (uint32_t)(t->cell_w + 0.5);
  size.cell_height = (uint32_t)(t->cell_h + 0.5);
  size.screen_width = (uint32_t)(t->cols * t->cell_w + 0.5);
  size.screen_height = (uint32_t)(t->rows * t->cell_h + 0.5);
  ghostty_mouse_encoder_setopt(t->mouse, GHOSTTY_MOUSE_ENCODER_OPT_SIZE, &size);
  ghostty_mouse_encoder_setopt(t->probe, GHOSTTY_MOUSE_ENCODER_OPT_SIZE, &size);
}

static void send_mouse(Term *t, int button, int action, int col, int row) {
  if (t->cell_w <= 0 || t->cell_h <= 0) return;

  GhosttyMouseEvent ev = NULL;
  if (ghostty_mouse_event_new(NULL, &ev) != GHOSTTY_SUCCESS) return;
  ghostty_mouse_event_set_action(
      ev, action == 0 ? GHOSTTY_MOUSE_ACTION_PRESS : GHOSTTY_MOUSE_ACTION_RELEASE);
  ghostty_mouse_event_set_button(ev, (GhosttyMouseButton)button);

  /* The middle of the cell: a hit test can only name a cell, so the exact
   * point inside it is arbitrary as long as it lands in the right one. */
  GhosttyMousePosition pos = {
      .x = (float)(col * t->cell_w + t->cell_w / 2),
      .y = (float)(row * t->cell_h + t->cell_h / 2),
  };
  ghostty_mouse_event_set_position(ev, pos);

  ghostty_mouse_encoder_setopt_from_terminal(t->mouse, t->term);
  char buf[64];
  size_t len = 0;
  if (ghostty_mouse_encoder_encode(t->mouse, ev, buf, sizeof(buf), &len) == GHOSTTY_SUCCESS &&
      len > 0) {
    write_all(t->master, buf, len);
  }
  ghostty_mouse_event_free(ev);
}

/* The encoder produces nothing at all when the app has not enabled mouse
 * reporting, which makes an empty encoding the mode test. */
static bool mouse_reporting(Term *t) {
  GhosttyMouseEvent ev = NULL;
  if (ghostty_mouse_event_new(NULL, &ev) != GHOSTTY_SUCCESS) return false;
  ghostty_mouse_event_set_action(ev, GHOSTTY_MOUSE_ACTION_PRESS);
  ghostty_mouse_event_set_button(ev, GHOSTTY_MOUSE_BUTTON_LEFT);
  GhosttyMousePosition pos = {.x = 0, .y = 0};
  ghostty_mouse_event_set_position(ev, pos);

  ghostty_mouse_encoder_setopt_from_terminal(t->probe, t->term);
  char buf[8];
  size_t len = 0;
  ghostty_mouse_encoder_encode(t->probe, ev, buf, sizeof(buf), &len);
  ghostty_mouse_event_free(ev);
  return len > 0;
}

/* Keys the panel can capture are forwarded as encoded key events. libghostty
 * converts them to the right escape sequence for the mode the running program
 * selected, which hand-written byte strings cannot do.
 *
 * The table is the whole modifier and function-key set, not a sample: a panel
 * chord that reaches the shell and is missing here is silently lost, and which
 * chords a TUI needs (ctrl+b for herdr, f5 for btop, ctrl+space for a prompt)
 * is not something this file can predict. Printable characters do not appear
 * here at all, because the panel types those as text. */
#define CTRL_LETTERS(mods, prefix, letters)                                     \
  {prefix "a", GHOSTTY_KEY_A, mods, letters "a"},                              \
      {prefix "b", GHOSTTY_KEY_B, mods, letters "b"},                          \
      {prefix "c", GHOSTTY_KEY_C, mods, letters "c"},                          \
      {prefix "d", GHOSTTY_KEY_D, mods, letters "d"},                          \
      {prefix "e", GHOSTTY_KEY_E, mods, letters "e"},                          \
      {prefix "f", GHOSTTY_KEY_F, mods, letters "f"},                          \
      {prefix "g", GHOSTTY_KEY_G, mods, letters "g"},                          \
      {prefix "h", GHOSTTY_KEY_H, mods, letters "h"},                          \
      {prefix "i", GHOSTTY_KEY_I, mods, letters "i"},                          \
      {prefix "j", GHOSTTY_KEY_J, mods, letters "j"},                          \
      {prefix "k", GHOSTTY_KEY_K, mods, letters "k"},                          \
      {prefix "l", GHOSTTY_KEY_L, mods, letters "l"},                          \
      {prefix "m", GHOSTTY_KEY_M, mods, letters "m"},                          \
      {prefix "n", GHOSTTY_KEY_N, mods, letters "n"},                          \
      {prefix "o", GHOSTTY_KEY_O, mods, letters "o"},                          \
      {prefix "p", GHOSTTY_KEY_P, mods, letters "p"},                          \
      {prefix "q", GHOSTTY_KEY_Q, mods, letters "q"},                          \
      {prefix "r", GHOSTTY_KEY_R, mods, letters "r"},                          \
      {prefix "s", GHOSTTY_KEY_S, mods, letters "s"},                          \
      {prefix "t", GHOSTTY_KEY_T, mods, letters "t"},                          \
      {prefix "u", GHOSTTY_KEY_U, mods, letters "u"},                          \
      {prefix "v", GHOSTTY_KEY_V, mods, letters "v"},                          \
      {prefix "w", GHOSTTY_KEY_W, mods, letters "w"},                          \
      {prefix "x", GHOSTTY_KEY_X, mods, letters "x"},                          \
      {prefix "y", GHOSTTY_KEY_Y, mods, letters "y"},                          \
      {prefix "z", GHOSTTY_KEY_Z, mods, letters "z"},

#define CTRL_PUNCT(mods, prefix)                                                \
  {prefix "minus", GHOSTTY_KEY_MINUS, mods, "-"},                              \
      {prefix "equal", GHOSTTY_KEY_EQUAL, mods, "="},                          \
      {prefix "bracketleft", GHOSTTY_KEY_BRACKET_LEFT, mods, "["},             \
      {prefix "bracketright", GHOSTTY_KEY_BRACKET_RIGHT, mods, "]"},           \
      {prefix "backslash", GHOSTTY_KEY_BACKSLASH, mods, "\\"},                 \
      {prefix "semicolon", GHOSTTY_KEY_SEMICOLON, mods, ";"},                  \
      {prefix "apostrophe", GHOSTTY_KEY_QUOTE, mods, "'"},                    \
      {prefix "grave", GHOSTTY_KEY_BACKQUOTE, mods, "`"},                      \
      {prefix "comma", GHOSTTY_KEY_COMMA, mods, ","},                          \
      {prefix "period", GHOSTTY_KEY_PERIOD, mods, "."},                        \
      {prefix "slash", GHOSTTY_KEY_SLASH, mods, "/"},                          \
      {prefix "space", GHOSTTY_KEY_SPACE, mods, " "},

#define ALT_KEYS(mods, prefix)                                                  \
  {prefix "left", GHOSTTY_KEY_ARROW_LEFT, mods, NULL},                         \
      {prefix "right", GHOSTTY_KEY_ARROW_RIGHT, mods, NULL},                   \
      {prefix "up", GHOSTTY_KEY_ARROW_UP, mods, NULL},                         \
      {prefix "down", GHOSTTY_KEY_ARROW_DOWN, mods, NULL},

#define FN_KEYS(prefix)                                                         \
  {prefix "f1", GHOSTTY_KEY_F1, 0, NULL},                                      \
      {prefix "f2", GHOSTTY_KEY_F2, 0, NULL},                                  \
      {prefix "f3", GHOSTTY_KEY_F3, 0, NULL},                                  \
      {prefix "f4", GHOSTTY_KEY_F4, 0, NULL},                                  \
      {prefix "f5", GHOSTTY_KEY_F5, 0, NULL},                                  \
      {prefix "f6", GHOSTTY_KEY_F6, 0, NULL},                                  \
      {prefix "f7", GHOSTTY_KEY_F7, 0, NULL},                                  \
      {prefix "f8", GHOSTTY_KEY_F8, 0, NULL},                                  \
      {prefix "f9", GHOSTTY_KEY_F9, 0, NULL},                                  \
      {prefix "f10", GHOSTTY_KEY_F10, 0, NULL},                                \
      {prefix "f11", GHOSTTY_KEY_F11, 0, NULL},                                \
      {prefix "f12", GHOSTTY_KEY_F12, 0, NULL},

static const struct {
  const char *name;
  GhosttyKey key;
  GhosttyMods mods;
  const char *utf8;
} KEY_TABLE[] = {
    {"enter", GHOSTTY_KEY_ENTER, 0, "\r"},
    {"return", GHOSTTY_KEY_ENTER, 0, "\r"},
    {"tab", GHOSTTY_KEY_TAB, 0, "\t"},
    {"shift+tab", GHOSTTY_KEY_TAB, GHOSTTY_MODS_SHIFT, NULL},
    {"backspace", GHOSTTY_KEY_BACKSPACE, 0, "\x7f"},
    {"delete", GHOSTTY_KEY_DELETE, 0, NULL},
    {"escape", GHOSTTY_KEY_ESCAPE, 0, "\x1b"},
    {"up", GHOSTTY_KEY_ARROW_UP, 0, NULL},
    {"down", GHOSTTY_KEY_ARROW_DOWN, 0, NULL},
    {"left", GHOSTTY_KEY_ARROW_LEFT, 0, NULL},
    {"right", GHOSTTY_KEY_ARROW_RIGHT, 0, NULL},
    {"home", GHOSTTY_KEY_HOME, 0, NULL},
    {"end", GHOSTTY_KEY_END, 0, NULL},
    {"pageup", GHOSTTY_KEY_PAGE_UP, 0, NULL},
    {"page_down", GHOSTTY_KEY_PAGE_DOWN, 0, NULL},
    {"page_up", GHOSTTY_KEY_PAGE_UP, 0, NULL},
    {"insert", GHOSTTY_KEY_INSERT, 0, NULL},
    {"space", GHOSTTY_KEY_SPACE, 0, " "},
    {"ctrl+tab", GHOSTTY_KEY_TAB, GHOSTTY_MODS_CTRL, NULL},
    {"ctrl+shift+tab", GHOSTTY_KEY_TAB, GHOSTTY_MODS_CTRL | GHOSTTY_MODS_SHIFT, NULL},
    CTRL_LETTERS(GHOSTTY_MODS_CTRL, "ctrl+", "a")
    CTRL_LETTERS(GHOSTTY_MODS_CTRL | GHOSTTY_MODS_SHIFT, "ctrl+shift+", "A")
    CTRL_PUNCT(GHOSTTY_MODS_CTRL, "ctrl+")
    ALT_KEYS(GHOSTTY_MODS_ALT, "alt+")
    ALT_KEYS(GHOSTTY_MODS_SHIFT | GHOSTTY_MODS_ALT, "shift+alt+")
    FN_KEYS("")
    {NULL, GHOSTTY_KEY_UNIDENTIFIED, 0, NULL},
};

static void send_key(Term *t, const char *name) {
  for (size_t i = 0; KEY_TABLE[i].name != NULL; i++) {
    if (strcmp(KEY_TABLE[i].name, name) != 0) continue;

    GhosttyKeyEvent ev = NULL;
    if (ghostty_key_event_new(NULL, &ev) != GHOSTTY_SUCCESS) return;
    ghostty_key_event_set_key(ev, KEY_TABLE[i].key);
    ghostty_key_event_set_action(ev, GHOSTTY_KEY_ACTION_PRESS);
    ghostty_key_event_set_mods(ev, KEY_TABLE[i].mods);
    if (KEY_TABLE[i].utf8 != NULL) {
      ghostty_key_event_set_utf8(ev, KEY_TABLE[i].utf8, strlen(KEY_TABLE[i].utf8));
    }

    /* Follow the modes the running program selected (cursor-key application,
     * Kitty keyboard protocol, modifyOtherKeys). */
    ghostty_key_encoder_setopt_from_terminal(t->enc, t->term);

    char buf[128];
    size_t len = 0;
    if (ghostty_key_encoder_encode(t->enc, ev, buf, sizeof(buf), &len) == GHOSTTY_SUCCESS && len > 0) {
      write_all(t->master, buf, len);
    }
    ghostty_key_event_free(ev);
    return;
  }
  fprintf(stderr, "ghostty-term: unknown key '%s'\n", name);
}

/* The theme arrives as one comma separated line: the default foreground, the
 * default background, then all 256 palette entries. The plugin owns the
 * palette (it is the shell's own palette file), so the helper only parses. */
static bool parse_hex_color(const char *token, GhosttyColorRgb *out) {
  if (token[0] == '#') token++;
  if (strlen(token) < 6) return false;
  unsigned value = 0;
  for (int i = 0; i < 6; i++) {
    char c = token[i];
    unsigned digit;
    if (c >= '0' && c <= '9') digit = (unsigned)(c - '0');
    else if (c >= 'a' && c <= 'f') digit = (unsigned)(c - 'a') + 10;
    else if (c >= 'A' && c <= 'F') digit = (unsigned)(c - 'A') + 10;
    else return false;
    value = value * 16 + digit;
  }
  out->r = (uint8_t)((value >> 16) & 0xFF);
  out->g = (uint8_t)((value >> 8) & 0xFF);
  out->b = (uint8_t)(value & 0xFF);
  return true;
}

static void set_palette(Term *t, char *line) {
  GhosttyColorRgb colors[258];
  unsigned count = 0;
  char *save = NULL;
  for (char *token = strtok_r(line, ",", &save); token != NULL && count < 258;
       token = strtok_r(NULL, ",", &save)) {
    if (!parse_hex_color(token, &colors[count])) {
      fprintf(stderr, "ghostty-term: bad color '%s' in palette\n", token);
      return;
    }
    count++;
  }
  if (count != 258) {
    fprintf(stderr, "ghostty-term: palette needs 258 colors, got %u\n", count);
    return;
  }

  GhosttyColorRgb foreground = colors[0];
  GhosttyColorRgb background = colors[1];
  if (ghostty_terminal_set(t->term, GHOSTTY_TERMINAL_OPT_COLOR_FOREGROUND, &foreground) != GHOSTTY_SUCCESS ||
      ghostty_terminal_set(t->term, GHOSTTY_TERMINAL_OPT_COLOR_BACKGROUND, &background) != GHOSTTY_SUCCESS ||
      ghostty_terminal_set(t->term, GHOSTTY_TERMINAL_OPT_COLOR_PALETTE, colors + 2) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: the terminal rejected the palette\n");
  }
}

static void resize_term(Term *t, uint16_t cols, uint16_t rows) {
  if (cols == 0 || rows == 0 || (cols == t->cols && rows == t->rows)) return;
  if (ghostty_terminal_resize(t->term, cols, rows, 0, 0) != GHOSTTY_SUCCESS) return;
  t->cols = cols;
  t->rows = rows;

  struct winsize ws = {0};
  ws.ws_col = cols;
  ws.ws_row = rows;
  ioctl(t->master, TIOCSWINSZ, &ws);
}

/* Returns -1 when the helper must quit. */
static int run_command(Term *t, char *line, bool *force) {
  switch (line[0]) {
    case 'i': {
      char text[16384];
      size_t n = unescape(text, sizeof(text), line + 1);
      if (n > 0) write_all(t->master, text, n);
      break;
    }
    case 's': {
      GhosttyTerminalScrollViewport sv;
      memset(&sv, 0, sizeof(sv));
      sv.tag = GHOSTTY_SCROLL_VIEWPORT_DELTA;
      sv.value.delta = (intptr_t)strtol(line + 1, NULL, 10);
      ghostty_terminal_scroll_viewport(t->term, sv);
      break;
    }
    case 'z': {
      unsigned c = 0, r = 0;
      if (sscanf(line + 1, "%ux%u", &c, &r) == 2 && c > 0 && r > 0 && c <= 1000 && r <= 1000) {
        resize_term(t, (uint16_t)c, (uint16_t)r);
      }
      break;
    }
    case 'k':
      send_key(t, line + 1);
      break;
    case 'm': {
      /* m<button>,<action>,<col>,<row>: action 0 is press, 1 is release. */
      int button = 0, action = 0, col = 0, row = 0;
      if (sscanf(line + 1, "%d,%d,%d,%d", &button, &action, &col, &row) == 4 && button >= 1 &&
          button <= 3 && col >= 0 && row >= 0) {
        send_mouse(t, button, action, col, row);
      }
      break;
    }
    case 'g': {
      /* g<cell width>x<cell height>, in surface pixels. */
      double w = 0, h = 0;
      if (sscanf(line + 1, "%lfx%lf", &w, &h) == 2 && w > 0 && h > 0) {
        t->cell_w = w;
        t->cell_h = h;
        set_mouse_geometry(t);
      }
      break;
    }
    case 'p':
      set_palette(t, line + 1);
      *force = true;
      break;
    case 'f':
      *force = true;
      break;
    case 'q':
      return -1;
    default:
      break;
  }
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 4) {
    fprintf(stderr, "usage: %s <fifo-path> <cols> <rows> [shell]\n", argv[0]);
    return 2;
  }

  const char *fifo_path = argv[1];
  uint16_t cols = (uint16_t)strtoul(argv[2], NULL, 10);
  uint16_t rows = (uint16_t)strtoul(argv[3], NULL, 10);
  if (cols == 0) cols = 100;
  if (rows == 0) rows = 28;
  const char *env_shell = getenv("SHELL");
  const char *shell = argc > 4 ? argv[4] : (env_shell ? env_shell : "/bin/sh");

  signal(SIGPIPE, SIG_IGN);

  if (mkfifo(fifo_path, 0600) != 0 && errno != EEXIST) {
    fprintf(stderr, "ghostty-term: mkfifo %s: %s\n", fifo_path, strerror(errno));
    return 1;
  }
  /* O_RDWR keeps a writer on this end, so poll never reports POLLHUP and the
   * helper can sit idle between the plugin's one-shot writes. */
  int fifo = open(fifo_path, O_RDWR | O_NONBLOCK);
  if (fifo < 0) {
    fprintf(stderr, "ghostty-term: open %s: %s\n", fifo_path, strerror(errno));
    return 1;
  }

  Term t;
  memset(&t, 0, sizeof(t));
  /* libghostty-vt takes the geometry as arguments of ghostty_terminal_new and
   * keeps the scrollback limit as a separate option. Keep 10000 lines of
   * history, because the `s<n>` command needs history to scroll. */
  if (ghostty_terminal_new(NULL, &t.term, cols, rows) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: terminal init failed\n");
    return 1;
  }
  size_t max_scrollback = 10000;
  if (ghostty_terminal_set(t.term, GHOSTTY_TERMINAL_OPT_SCROLLBACK_MAX_LINES,
                           &max_scrollback) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: scrollback limit rejected\n");
  }
  t.cols = cols;
  t.rows = rows;

  /* The callbacks are registered before the shell exists; the userdata is the
   * address of t.master, which forkpty fills in below. */
  ghostty_terminal_set(t.term, GHOSTTY_TERMINAL_OPT_USERDATA, &t.master);
  ghostty_terminal_set(t.term, GHOSTTY_TERMINAL_OPT_WRITE_PTY, on_write_pty);
  ghostty_terminal_set(t.term, GHOSTTY_TERMINAL_OPT_DEVICE_ATTRIBUTES, on_device_attributes);

  struct winsize ws = {0};
  ws.ws_col = cols;
  ws.ws_row = rows;

  /* A NULL termios keeps the kernel's pty defaults, which already carry sane
   * c_cc values. Building termios by hand would zero VINTR and VEOF. */
  int master = -1;
  pid_t pid = forkpty(&master, NULL, NULL, &ws);
  if (pid < 0) {
    fprintf(stderr, "ghostty-term: forkpty: %s\n", strerror(errno));
    return 1;
  }
  if (pid == 0) {
    setenv("TERM", "xterm-256color", 1);
    setenv("COLORTERM", "truecolor", 1);
    execl(shell, shell, "-l", (char *)NULL);
    execl(shell, shell, (char *)NULL);
    fprintf(stderr, "ghostty-term: exec %s: %s\n", shell, strerror(errno));
    _exit(127);
  }
  t.master = master;

  int flags = fcntl(master, F_GETFL, 0);
  if (flags >= 0) fcntl(master, F_SETFL, flags | O_NONBLOCK);

  GhosttyRenderState st = NULL;
  if (ghostty_render_state_new(NULL, &st) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: render state init failed\n");
    return 1;
  }
  if (ghostty_key_encoder_new(NULL, &t.enc) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: key encoder init failed\n");
    return 1;
  }
  if (ghostty_mouse_encoder_new(NULL, &t.mouse) != GHOSTTY_SUCCESS ||
      ghostty_mouse_encoder_new(NULL, &t.probe) != GHOSTTY_SUCCESS) {
    fprintf(stderr, "ghostty-term: mouse encoder init failed\n");
    return 1;
  }

  printf("{\"t\":\"init\",\"c\":%u,\"r\":%u}\n", (unsigned)cols, (unsigned)rows);
  fflush(stdout);
  emit_frame(&t, st, true);

  char line[8192];
  size_t line_len = 0;
  bool line_overflow = false;
  char inbuf[65536];
  long last_emit = now_ms();
  bool force = false;
  bool pending = false;
  bool quitting = false;

  while (!quitting) {
    struct pollfd fds[2];
    fds[0].fd = master;
    fds[0].events = POLLIN;
    fds[0].revents = 0;
    fds[1].fd = fifo;
    fds[1].events = POLLIN;
    fds[1].revents = 0;

    long wait = FRAME_MIN_MS - (now_ms() - last_emit);
    int timeout = wait > 0 ? (int)wait : 0;

    if (poll(fds, 2, timeout) < 0) {
      if (errno == EINTR) continue;
      break;
    }

    bool wrote = false;
    if (fds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
      for (;;) {
        ssize_t n = read(master, inbuf, sizeof(inbuf));
        if (n > 0) {
          ghostty_terminal_vt_write(t.term, (const uint8_t *)inbuf, (size_t)n);
          wrote = true;
          continue;
        }
        if (n == 0 || (n < 0 && errno == EIO)) {
          printf("{\"t\":\"exit\"}\n");
          fflush(stdout);
          quitting = true;
          break;
        }
        if (n < 0 && errno == EINTR) continue;
        break;
      }
      if (quitting) break;
    }

    if (fds[1].revents & POLLIN) {
      for (;;) {
        ssize_t n = read(fifo, inbuf, sizeof(inbuf));
        if (n <= 0) break;
        for (ssize_t i = 0; i < n; i++) {
          char ch = inbuf[i];
          if (ch == '\n') {
            if (!line_overflow && line_len > 0) {
              line[line_len] = '\0';
              if (run_command(&t, line, &force) == -1) {
                quitting = true;
                break;
              }
            }
            line_len = 0;
            line_overflow = false;
          } else if (line_len + 1 < sizeof(line)) {
            line[line_len++] = ch;
          } else {
            line_overflow = true;
          }
        }
        if (quitting) break;
      }
      if (quitting) break;
    }

    long now = now_ms();
    if (wrote) pending = true;
    /* A gated write must stay pending: the poll timeout below is the deadline,
     * and without this flag the coalesced frame would never be emitted when no
     * further output arrives. */
    if (force || (pending && now - last_emit >= FRAME_MIN_MS)) {
      emit_frame(&t, st, force);
      force = false;
      pending = false;
      last_emit = now_ms();
    }
  }

  close(master);
  close(fifo);
  unlink(fifo_path);
  ghostty_key_encoder_free(t.enc);
  ghostty_mouse_encoder_free(t.mouse);
  ghostty_mouse_encoder_free(t.probe);
  ghostty_render_state_free(st);
  ghostty_terminal_free(t.term);
  return 0;
}
