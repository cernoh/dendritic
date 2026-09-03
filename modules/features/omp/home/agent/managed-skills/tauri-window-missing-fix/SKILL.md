---
name: tauri-window-missing-fix
description: "Fix nix run Tauri building but showing no window (10x10 InputOnly) — check tauri.conf.json app.windows, store plugin, flake.nix dbus/zlib and PKG_CONFIG_PATH, plus deterministic Xvfb+openbox window-id capture."
---

# Tauri Window Missing — `nix run` builds but no interface appears

When `nix run` compiles (VITE ready, `config.init portable=false`, no panic) yet no Tauri window appears, check these in order. On this repo the symptom was a single `10x10 InputOnly IsUnMapped` window (`xwininfo -root -tree` showed `0x400001 10x10 InputOnly`) — the real WebView never existed.

## 1. `src-tauri/tauri.conf.json` must declare a window

Tauri v2 only creates windows listed in `app.windows` (or built via `WebviewWindowBuilder` in Rust). If `app` has only `withGlobalTauri`, no viewable window is created.

```json
"app": {
  "withGlobalTauri": true,
  "windows": [{ "label": "main", "title": "Stremio Accru", "width": 1280, "height": 720 }]
}
```

Verify after fix: `xwininfo -root -tree -display :98 | grep "Stremio Accru"` should show `1280x720 IsViewable` (e.g. `0x400003`), not `10x10 InputOnly IsUnMapped`.

## 2. `plugins.store` shape

`tauri_plugin_store` expects a unit, not a map. `"store": {}` panics:
`PluginInitialization("store", "invalid type: map, expected unit")` at `src/lib.rs:51`. Remove the key or configure correctly.

## 3. `flake.nix` Tauri system deps + PKG_CONFIG_PATH

Missing deps manifest as `pkg-config` failures:

- `libdbus-sys` → needs `dbus`
- `gdk-sys` → needs `zlib` (note: `zlib.pc` lives in `share/pkgconfig`, not `lib/pkgconfig`)

```nix
tauriDeps = with pkgs; [ pkg-config gobject-introspection openssl glib gtk3 webkitgtk_4_1 libsoup_3 cairo gdk-pixbuf librsvg pango atk harfbuzz dbus zlib mpv ];
devRunner.text = ''
  export PKG_CONFIG_PATH="${pkgs.lib.makeSearchPathOutput "dev" "lib/pkgconfig" tauriDeps}:${pkgs.lib.makeSearchPathOutput "dev" "share/pkgconfig" tauriDeps}:${pkgs.mpv}/lib/pkgconfig:''${PKG_CONFIG_PATH:-}"
'';
```

Apply to both `devRunner` and `buildRunner` (and `shellHook` via `makeSearchPathOutput` or `nativeBuildInputs`).

## 4. Deterministic screenshot — avoid `xwd -root` blank

Bare `Xvfb` without a WM: `xwd -root` grabs only root backing store (black), so a painted child still looks blank. Capture **by window id** under `Xvfb + openbox`:

```bash
rm -f /tmp/.X98-lock
Xvfb :98 -screen 0 1920x1080x24 &; sleep 2
DISPLAY=:98 openbox &; sleep 2
# in repo:
nix develop -c bash -c "deno task dev" > /tmp/vite.log 2>&1 &  # wait VITE ready
WAYLAND_DISPLAY= GDK_BACKEND=x11 DISPLAY=:98 WEBKIT_DISABLE_DMABUF_RENDERER=1 \
  nix develop -c bash -c "./src-tauri/target/debug/stremio-accru" & # or nix run
# poll for 0x... "Stremio Accru" 1280x720
DISPLAY=:98 xwininfo -root -tree | grep -E "Stremio Accru"
WIN=$(DISPLAY=:98 xwininfo -root -tree | grep "Stremio Accru" | grep "1280x720" | awk '{print $1}' | head -1)
DISPLAY=:98 xwininfo -id $WIN  # should be Class: InputOutput Map State: IsViewable 1280x720
DISPLAY=:98 xwd -id $WIN -out /tmp/win.xwd && magick /tmp/win.xwd /tmp/win.png
```

Sanity: `xclock` under same Xvfb+openbox should produce ~9K png via `xwd -root` — proves pipeline works; Tauri root capture alone will stay 585B blank if you forget window-id.

## 5. Checklist

- `cargo run` log shows `config.init` without `PluginInitialization` panic
- `ss -tlnp | grep 1420` + `curl http://127.0.0.1:1420/ | grep "<h1>"` proves vite content
- `chromium --headless --screenshot http://127.0.0.1:1420` shows Svelte UI (Hero/Metadata/Player)
- `xwininfo -root -tree` shows `1280x720 IsViewable`, `xwd -id $WIN` → 3–4M xwd / ~50K png with wizard
