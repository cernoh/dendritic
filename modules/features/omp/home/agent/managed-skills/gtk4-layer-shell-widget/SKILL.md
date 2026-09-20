---
name: gtk4-layer-shell-widget
description: "Ship a GTK4 gtk4-layer-shell desktop widget from a Nix flake and verify it on a live Wayland session: the LD_PRELOAD interposition trap, lib.getLib for pango typelibs, NON_UNIQUE single-instance exits, bundling a serif font, grim-based pixel proof, and why wlrctl clicks reach no surface on mango"
---

Ship a GTK4 + gtk4-layer-shell desktop widget from a Nix flake, and verify it on a live Wayland session. Proven on NIXPC (mango + Noctalia, GTK 4.22, gtk4-layer-shell 1.3.0, 2026-09-19).

## Flake wiring (the three traps)

1. **Preload the layer-shell library.** GTK loads `libwayland-client` before
   `gtk4-layer-shell` can interpose, so `gtk_layer_init_for_window` fails with
   "GtkWindow is not a layer surface" *and returns silently*. The window then
   becomes an ordinary toplevel, which a tiling compositor tiles. Wrapper line:

   ```nix
   --prefix LD_PRELOAD : ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
   ```

   The packaged `liblayer-shell-preload.so` does NOT fix this; use the real
   library. Detect the failure with `LayerShell.is_layer_window(win)` and with
   `wlrctl toplevel list` (a layer surface never appears there).

2. **Typelibs and libraries need `lib.getLib`.** `pkgs.pango` interpolates to
   its default output, which is `bin` and holds no typelib, so
   `lib.makeSearchPath "lib/girepository-1.0" [ pkgs.pango ]` silently drops it
   and GTK dies with `PangoCairo not found`. Map the stack through `lib.getLib`:

   ```nix
   gtkStack = map lib.getLib ([ pkgs.glib pkgs.pango pkgs.cairo pkgs.gdk-pixbuf
     pkgs.graphene pkgs.harfbuzz pkgs.gtk4 pkgs.gtk4-layer-shell
     pkgs.gobject-introspection ] ++ pkgs.gtk4.buildInputs
     ++ pkgs.gtk4.propagatedBuildInputs);
   typelibPath = lib.makeSearchPath "lib/girepository-1.0" gtkStack;
   libraryPath = lib.makeLibraryPath gtkStack;
   ```

3. **Use `Gio.ApplicationFlags.NON_UNIQUE`.** A `GtkApplication` is
   single-instance per session bus: a second run hands off to the first and
   exits 0 in under a second with no output, silently ignoring its flags. This
   looks exactly like a crash and wastes a debugging cycle — check
   `systemctl --user is-active`, the journal, and whether another instance runs.

## Bundled font without a system font package

`fc-match "EB Garamond"` returning DejaVu means the font must come from the
flake. Register the files into the Pango font map at startup:

```python
font_map = window.get_pango_context().get_font_map()   # NOT display.get_default_seat()
font_map.add_font_file("/path/EBGaramond12-Regular.otf")  # Pango >= 1.56
```

`Gdk.Seat` has no `create_pango_context`; that call raises `AttributeError` and,
if unhandled inside a startup hook, costs you the font only. Prove the family is
really used by pixel comparison, not by eye: two runs at the same seed must give
byte-identical captures, and `--font "No Such Serif At All"` must change
thousands of pixels (measured: 9.5% of a 540x220 card, max channel delta 215).

## Visual verification on the live session

- The hub broker can be dead: start the widget with
  `systemd-run --user --collect --unit=<name> --setenv=WAYLAND_DISPLAY=wayland-0 --setenv=XDG_RUNTIME_DIR=/run/user/1000 <wrapper>`.
- `grim -o <OUTPUT>` captures one output; `grim -g "x,y WxH"` captures a region
  of the whole layout. The two flags are mutually exclusive.
- Output positions come from `wlr-randr` (`Position: 3840,0`). With three
  1920x1080 outputs the layout spans 5760x1080; a widget anchored bottom-right
  sits near `x = 5760-44-470`.
- Ask a vision model for the bounding box, then crop that region with `-g` for a
  readable confirmation.
- Compare captures as PPM (`grim -t ppm`): parse the P6 header and diff pixels.
  The screen must be static between the two shots for the difference to mean
  anything.

## Synthetic input does not work here

`wlrctl pointer move` moves the cursor, but `wlrctl pointer click` reaches **no
surface** on mango: the Noctalia bar ignores it, and a bare GTK window with
`GestureClick` plus `EventControllerMotion` logs no event at all. The same
result holds in a headless `sway` (`WLR_BACKENDS=headless`,
`WLR_LIBINPUT_NO_DEVICES=1`, `WLR_RENDERER=pixman`) on a second socket. So a
click handler cannot be proven with wlrctl on this host; say so instead of
claiming it works. A headless sway on `wayland-1` is still the best clean
environment for rendering checks (`grim` works against it). Use `xdotool` on a
`GDK_BACKEND=x11` display for real click events.

## Grounded text corpora

When a corpus quotes published works, ground every entry: fetch the source page
raw wikitext (`?title=X&action=raw`), copy contiguous spans only, and keep a
`source` URL per entry. Verify with a script that fetches each page and asserts
containment after folding typographic punctuation, `--` vs `-`, wiki links and
`'''` markup. Build the request **after** rewriting the URL to `action=raw`, or
you fetch rendered HTML and get mysterious misses on bolded lines.
