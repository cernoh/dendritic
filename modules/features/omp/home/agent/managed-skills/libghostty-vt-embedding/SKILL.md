---
name: libghostty-vt-embedding
description: "Embed libghostty-vt (Ghostty's terminal emulator core) from nixpkgs in a C helper: the pkgs.ghostty-vs-pkgs.libghostty-vt soname trap, dev-output headers, the terminal/render-state/key-encoder API as it exists on the pinned rev, PTY+FIFO wiring, and the verification recipe. Use when building a terminal emulator into a host that cannot link C (sandboxed scripting runtimes), or when libghostty headers appear \"missing\"."
---

# Embedding libghostty-vt from nixpkgs

libghostty-vt is Ghostty's terminal emulator core as a standalone C library: VT parsing, terminal state (cursor, scrollback, reflow), render state, formatter, key encoding. It does **not** do windowing, rendering, PTY management, or config — the embedder supplies all of that.

Use it when a host cannot link C (e.g. a sandboxed scripting runtime with no FFI): build a helper process that owns the PTY + terminal state and reports the screen to the host.

## 1. The two-package trap — check this first

nixpkgs ships **two** packages whose libraries share the soname `libghostty-vt.so.0`:

| Package | Contents |
|---|---|
| `pkgs.ghostty` | The emulator binary. Its `libghostty-vt` is **parser-only**: ~648 symbols, all `key`/`sgr`/`osc`/`paste`/`simd`. **No** `ghostty_terminal_*`, `ghostty_render_state_*`, `ghostty_formatter_*`. Its `include/ghostty/vt.h` includes ~27 headers (`terminal.h`, `render.h`, …) that it does **not** install → `#include <ghostty/vt.h>` fails with `unknown type name 'GhosttyTerminal'`. |
| `pkgs.libghostty-vt` | The full API: terminal state, render state, formatter, key encoder. |

Always use `pkgs.libghostty-vt`.

```bash
nix eval --json nixpkgs#libghostty-vt.outputs          # ["out","dev"]
nix eval --raw  nixpkgs#libghostty-vt.version
D=$(nix eval --raw nixpkgs#libghostty-vt.dev.outPath)
ls $D/include/ghostty/vt/    # terminal.h render.h formatter.h types.h style.h key/encoder.h
ls $D/share/pkgconfig/       # libghostty-vt.pc
```

**Headers are in the `dev` output, not `out`.** Compile via pkg-config (`libghostty-vt.pc` lives in `$dev/share/pkgconfig`); it emits the correct `-I` (dev) and `-L` (out).

Prove the binary bound the full library (the same soname makes a wrong pick silent):
```bash
patchelf --print-rpath ./binary                       # must point at libghostty-vt-<ver>/lib
nix-store -qR ./result | grep -c 'ghostty-1\.3\.1'    # must be 0
```

## 2. Trust the locked rev's headers, not GitHub main

The API is explicitly unstable and has already moved. On the pinned rev `0.1.0-unstable-2026-07-20`:

- `ghostty_terminal_new(alloc, &term, GhosttyTerminalOptions{cols,rows,max_scrollback})` — takes an **options struct**, not `(cols, rows)`.
- No `GHOSTTY_RENDER_STATE_DATA_COLORS` — use `ghostty_render_state_colors_get(state, &colors)`.
- No `GhosttyRenderStateCursor` sized struct — query `GHOSTTY_RENDER_STATE_DATA_CURSOR_VIEWPORT_X/_Y`, `..._CURSOR_VISIBLE`, `..._CURSOR_VIEWPORT_HAS_VALUE` individually.
- No `ghostty_render_state_clean` — clear dirty via `ghostty_render_state_set(st, GHOSTTY_RENDER_STATE_OPTION_DIRTY, &zero)`.

Compile against `$(pkg-config --cflags libghostty-vt)`. Blog posts and `main` headers disagree with the pinned rev; the compiler is the arbiter.

## 3. Core API

Create / drive:
```c
GhosttyTerminalOptions o = {0};
o.cols = 80; o.rows = 24; o.max_scrollback = 10000;
GhosttyTerminal t;
ghostty_terminal_new(NULL, &t, o);

ghostty_terminal_vt_write(t, bytes, len);            // feed PTY output
ghostty_terminal_resize(t, cols, rows, 0, 0);        // 0,0 = cell px unknown

uint16_t cols;  ghostty_terminal_get(t, GHOSTTY_TERMINAL_DATA_COLS, &cols);
size_t sbrows;  ghostty_terminal_get(t, GHOSTTY_TERMINAL_DATA_SCROLLBACK_ROWS, &sbrows);
ghostty_terminal_free(t);
```

Render state (per-cell fg/bg/glyphs — this is the path for a real screen):
```c
GhosttyRenderState st;
ghostty_render_state_new(NULL, &st);
ghostty_render_state_update(st, t);

GhosttyRenderStateColors c = GHOSTTY_INIT_SIZED(GhosttyRenderStateColors);
ghostty_render_state_colors_get(st, &c);             // .foreground .background .palette[256]

GhosttyRenderStateDirty d;
ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_DIRTY, &d);

// Create the iterator + cells container ONCE; reuse for every row.
GhosttyRenderStateRowIterator it;
GhosttyRenderStateRowCells  cells;
ghostty_render_state_row_iterator_new(NULL, &it);
ghostty_render_state_row_cells_new(NULL, &cells);
ghostty_render_state_get(st, GHOSTTY_RENDER_STATE_DATA_ROW_ITERATOR, &it);

while (ghostty_render_state_row_iterator_next(it)) {
  ghostty_render_state_row_get(it, GHOSTTY_RENDER_STATE_ROW_DATA_CELLS, &cells);
  while (ghostty_render_state_row_cells_next(cells)) {
    uint8_t gbuf[64];
    GhosttyBuffer gb = {.ptr = gbuf, .cap = sizeof gbuf};
    ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_GRAPHEMES_UTF8, &gb);

    GhosttyColorRgb fg;
    ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_FG_COLOR, &fg);

    GhosttyStyle s = GHOSTTY_INIT_SIZED(GhosttyStyle);
    ghostty_render_state_row_cells_get(cells, GHOSTTY_RENDER_STATE_ROW_CELLS_DATA_STYLE, &s);
    // s.bold .italic .inverse .invisible .strikethrough .underline
  }
}
```
`GHOSTTY_INVALID_VALUE` from `_FG_COLOR`/`_BG_COLOR` means "no explicit color" — fall back to the render-state default.

Key encoding (never hand-write escape bytes):
```c
GhosttyKeyEncoder enc;  ghostty_key_encoder_new(NULL, &enc);
GhosttyKeyEvent   ev;   ghostty_key_event_new(NULL, &ev);
ghostty_key_event_set_key(ev, GHOSTTY_KEY_C);              // W3C physical key code
ghostty_key_event_set_mods(ev, GHOSTTY_MODS_CTRL);         // SHIFT/CTRL/ALT/SUPER
ghostty_key_event_set_action(ev, GHOSTTY_KEY_ACTION_PRESS);
ghostty_key_event_set_utf8(ev, "c", 1);                    // for printable keys

ghostty_key_encoder_setopt_from_terminal(enc, t);          // follows the app's chosen mode
char out[128]; size_t n = 0;
if (ghostty_key_encoder_encode(enc, ev, out, sizeof out, &n) == GHOSTTY_SUCCESS && n)
  write(master, out, n);
```
`setopt_from_terminal` picks up cursor-key application mode, Kitty keyboard flags, modifyOtherKeys — which is why encoded output beats hardcoded strings.

## 4. PTY and FIFO wiring

- `forkpty(&master, NULL, NULL, &ws)` — **pass NULL termios.** Hand-building `struct termios` zeroes `c_cc` and kills `VINTR`/`VEOF`, so Ctrl+C and Ctrl+D stop working.
- Child: `setenv("TERM","xterm-256color",1)`, `COLORTERM=truecolor`, then `execl(shell, shell, "-l", NULL)` with a plain-exec fallback.
- Master: `O_NONBLOCK`. Treat `read()==0` **or** `errno==EIO` as "child gone".
- FIFO: `mkfifo(path, 0600)`; open `O_RDWR | O_NONBLOCK` so a writer on the read end always exists and `poll` never reports `POLLHUP` between one-shot writes; `unlink` on exit.
- Line protocol: a bare `\n` terminates a command, so a literal newline meant for the shell must travel as an escape (`\n` two chars) and be unescaped before `write(master, …)`.

## 5. Frame coalescing trap

If you rate-limit screen frames, a write that arrives *before* the gate must stay **pending**; a `bool wrote` consumed inside the gate drops the final update and the last output never renders. Track `pending` and let the `poll` timeout act as the deadline:

```c
if (wrote) pending = true;
if (force || (pending && now - last_emit >= MIN_MS)) { emit(); pending = false; last_emit = now(); }
```

## 6. Build recipe

```nix
{ lib, stdenv, pkg-config, libghostty-vt }:
stdenv.mkDerivation {
  pname = "helper"; version = "1.0.0";
  dontUnpack = true;                       # avoid copying the whole directory into the store
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libghostty-vt ];
  buildPhase = ''
    $CC -std=c11 -O2 -Wall -Wextra -Werror \
      $(pkg-config --cflags libghostty-vt) \
      ${./helper.c} \
      $(pkg-config --libs libghostty-vt) -o helper
  '';
  installPhase = "install -Dm755 helper $out/bin/helper";
}
```

- `${./helper.c}` keeps the source set to one file; the path must be visible to the flake source (tracked by git, or the eval sees a copy without it).
- Guard architectures: `lib.meta.availableOn stdenv.hostPlatform pkgs.libghostty-vt` — there is no `x86_64-darwin` build, and an unguarded attribute breaks flake-wide eval on darwin.

## 7. Verification recipe (what actually proves it)

1. **API PoC**: feed `\e[1;32m…` and `\e[2J\e[1;1H…`; assert cell fg resolves through the palette and the formatter output matches. Proves the pinned-rev API is what you think.
2. **PTY smoke test**: `setsid helper $FIFO 40 8 /bin/sh >frames.jsonl`, drive commands through the FIFO, print frames. (`setsid` so it survives the harness.)
3. **Prove key encoding against a real line editor** — this is the strongest check:
   - `ctrl+u` must kill the line **silently**. A literal `^U` echo means the shell received a raw byte, not an encoded key.
   - `up` must recall history. A literal `^[[A` on screen means nothing consumed the sequence.
   - `ctrl+c` must interrupt a running `sleep`.
   With readline active, both silent-kill and history-recall pass; without it, both fail visibly.
4. **Assert exact reconstructed row text**, not `substring`. Matching an *echoed* command passes for the wrong reason — require the command's *output* on its own row.
5. `nix-instantiate --parse` on every `.nix`; `nix build` the package; then check RPATH + closure (section 1).

## Pitfalls checklist

- Linked `pkgs.ghostty` instead of `pkgs.libghostty-vt` → missing `ghostty_terminal_*` at link time, or silent wrong soname at runtime.
- Used `out` headers instead of `dev` → headers "not found".
- Hand-built `termios` → no Ctrl+C / Ctrl+D.
- FIFO opened `O_RDONLY` → `poll` returns `POLLHUP` immediately between writes.
- Rate-limited frames without a `pending` flag → final output never renders.
- Trusted `main` headers over the locked rev → struct/argument mismatches.
