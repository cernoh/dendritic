---
name: stremio-mpv-mirror
description: Mirror Stremio shell-ng / linux-shell MPV inclusion in stremio-accru (Tauri + Nix)
---

# Stremio MPV Mirror — shell-ng → accru

When asked to "mirror how Stremio includes mpv" in `stremio-accru`, replicate both reference shells:

## References
- **shell-ng (Windows):** `Stremio/stremio-shell-ng` — `libmpv2 6.0.0`, vendored `libmpv-2_x64.zip` → `mpv-x64/mpv.lib` + `libmpv-2.dll`, `build.rs` `zip_extract::extract(Cursor::new(bytes),".",true)` + `cargo:rustc-link-arg=/LIBPATH:.\mpv-x64` + `cargo:rustc-env=ARCH=x64`, `create_mpv(HWND)` sets `wid`, `vo=gpu-next,gpu,` via `with_gpu_next_fallback`, `hwdec=auto`, `stream-lavf-o=reconnect...%23%408,429,500,502,503,504`, `d3d11-*`, `target-colorspace-hint`, `tone-mapping=bt.2390`, threads for events/display/message + HDR DisplayConfig poll.
- **linux-shell:** `stremio-linux-shell` — `libmpv2 5.0.3`, system `mpv-devel`, `GLArea` + `epoxy` + `RenderContext::new(OpenGl, WaylandDisplay)`, `vo=libmpv`, `glib::idle_add_local` signals.

## accru Layout
- `src-tauri/Cargo.toml`, `src-tauri/build.rs`, `src-tauri/src/player/desktop.rs`, `flake.nix`, `.gitignore`, `portable_config/mpv.conf`, `src-tauri/tauri.conf.json`.

## Steps
1. **Cargo.toml** — add `libmpv2 = { version="6", optional=true }`, `raw-window-handle = { version="0.6", optional=true }`, `zip-extract = { version="0.2", optional=true }`, `flume = "0.11"` to `[dependencies]`; `[build-dependencies] zip-extract optional`; `[features] zip-extract=["dep:zip-extract"]`, `desktop-player=["dep:libmpv2","dep:raw-window-handle","zip-extract"]`. Default stays mock.

2. **build.rs** — keep `tauri_build::build()` then Windows-only block: `TARGET` → `(arch, zip, flag)` (`x86_64→libmpv-2_x64.zip` / `aarch64→arm64`), gate on `CARGO_FEATURE_DESKTOP_PLAYER|ZIP_EXTRACT`, emit `cargo:rustc-env=ARCH`, `cargo:rustc-link-arg`, `rerun-if-changed`, `fs::read` + `#[cfg(feature="zip-extract")] zip_extract::extract`. Missing zip → `cargo:warning` fallback to pkg-config.

3. **player/desktop.rs** — `DesktopPlayer { state, app, mpv: Mutex<Option<Arc<Mpv>>> }` with `#[cfg(feature="desktop-player")]`. `resolve_wid` via `Manager::get_webview_window("main").window_handle()` → Win32/X11 wid, Wayland None. Copy `with_gpu_next_fallback` verbatim. `create_mpv(wid: Option<i64>)` mirrors shell-ng initializer (wid/title/terminal/msg-level/hwdec/stream-lavf-o/vo + windows d3d11 opts vs linux auto). `event_loop(client,app,state)` → `wait_event(0.1)` → `PropertyData` → `emit_property`, `EndFile→playback-ended`. Dual `#[async_trait] PlayerBackend` impls (mock vs real `with_mpv` calling `mpv.command/set_property/observe_property`).

4. **flake.nix** — `tauriDeps` includes `mpv`; `PKG_CONFIG_PATH` in `devRunner`/`buildRunner`/`shellHook` must include `${pkgs.mpv}/lib/pkgconfig` (not `.dev`) alongside openssl/webkitgtk.

5. **.gitignore** — `src-tauri/libmpv-2_*.zip` + `src-tauri/mpv-*/`.

6. **Verification** — `nix develop --command cargo check` and `cargo check --features desktop-player` must both succeed (fix `zip-extract` feature cfg and `mut client` warnings).

## Windows Bundle
Place `src-tauri/libmpv-2_x64.zip` from shell-ng releases before `cargo tauri build --features desktop-player`; ensure `libmpv-2.dll` shipped beside exe via `bundle.resources`.
