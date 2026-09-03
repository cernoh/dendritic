---
name: stremio-mpv-mirror-procedure
description: "Mirror Stremio's MPV inclusion (stremio-shell-ng Windows + stremio-linux-shell) into stremio-accru desktop player"
---

# Stremio MPV Mirror Procedure

Mirrors how Stremio includes MPV upstream into `stremio-accru` Tauri desktop player.

## Upstream references
- **shell-ng** (`Stremio/stremio-shell-ng`): Windows-only. `libmpv2 6.0.0` + `libmpv2-sys 4.0.1`, vendors `libmpv-2_x64.zip` → `mpv-x64/{mpv.lib,mpv.def,mpv.exp}` + `libmpv-2.dll` + `bin/{ffmpeg,ffprobe,*.dll}`. `build.rs`: `fs::read(zip)` + `zip_extract::extract(Cursor, ".", true)` + `cargo:rustc-link-arg=/LIBPATH:.\mpv-x64` + `cargo:rustc-env=ARCH=x64`. `src/stremio_app/stremio_player/player.rs:create_mpv(HWND)` sets `wid=HWND as i64`, `vo=gpu-next,gpu,` + `with_gpu_next_fallback`, `hwdec=auto`, `stream-lavf-o=reconnect...%23%408,429,500,502,503,504`, d3d11 `gpu-context/dither/tone-mapping=bt.2390`, event/display/message threads (`wait_event(0.1)`), `VideoReadyState`. Inno `setup/Stremio.iss [Files]` ships `libmpv-2.dll`.
- **linux-shell** (`Stremio/stremio-linux-shell`): `libmpv2 5.0.3`, system `mpv-devel` (`mpv.pc`), `GLArea` + `epoxy` + `RenderContext::new(OpenGl, WaylandDisplay)` `vo=libmpv`, signals `property-changed`/`playback-ended`.

## Steps to mirror in stremio-accru

1. **Cargo.toml** (`src-tauri/Cargo.toml`):
   - `[build-dependencies] zip-extract = { version="0.2", optional=true }`
   - `[dependencies] flume="0.11", libmpv2={version="6", optional=true}, raw-window-handle={version="0.6", optional=true}`
   - `[features] zip-extract=["dep:zip-extract"], desktop-player=["dep:libmpv2","dep:raw-window-handle","zip-extract"]` (default mock kept for tests/CI/mobile)

2. **build.rs** (`src-tauri/build.rs`):
   - Keep `tauri_build::build()`
   - Branch `TARGET`: `x86_64-pc-windows-msvc→(x64,libmpv-2_x64.zip,/LIBPATH:.\mpv-x64)`, `aarch64→arm64`
   - Guard `CARGO_FEATURE_DESKTOP_PLAYER`/`ZIP_EXTRACT`, emit `cargo:rustc-env=ARCH`, `cargo:rustc-link-arg`, `rerun-if-changed`
   - `fs::read` archive at `CARGO_MANIFEST_DIR/{archive}`, `zip_extract::extract(Cursor::new(bytes), manifest_dir, true)` under `#[cfg(feature="zip-extract")]`, else `cargo:warning` (no panic)

3. **DesktopPlayer** (`src-tauri/src/player/desktop.rs`):
   - `DesktopPlayer { state: Arc<PlayerState>, app: AppHandle, mpv: Mutex<Option<Arc<Mpv>>> #[cfg(desktop-player)], ... }`
   - `resolve_wid_raw` via `app.get_webview_window("main").window_handle().as_raw()` → `Win32(hwnd)→isize`, `Xlib/Xcb→isize`, `Wayland/AppKit→None`
   - `with_gpu_next_fallback(vo: String)→String` exact copy of shell-ng
   - `create_mpv(wid: Option<i64>)` → `Mpv::with_initializer` sets `wid`, `title`, `audio-client-name`, `terminal`, `msg-level`, `quiet`, `hwdec`, `stream-lavf-o`, `vo=with_gpu_next_fallback("gpu-next,gpu,")`, Windows `gpu-context=d3d11` block else `gpu-context=auto`, `disable_deprecated_events()`
   - `event_loop(client:Mpv, app, state)` → `loop { wait_event(0.1) → PropertyData::Str/Flag/Double/Int64 → emit_property, EndFile→playback-ended, Shutdown→break }`
   - Dual `#[async_trait] impl PlayerBackend`: mock when `!desktop-player`, real `with_mpv(|mpv| mpv.command/ set_property/ observe_property)` when enabled, keep `player:*` Tauri emits

4. **flake.nix**:
   - `tauriDeps` already includes `mpv`; add `PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.webkitgtk_4_1.dev}/lib/pkgconfig:${pkgs.mpv}/lib/pkgconfig"` to `devRunner`, `buildRunner`, `shellHook` (mirrors `mpv-devel`)

5. **.gitignore**: `src-tauri/libmpv-2_*.zip`, `src-tauri/mpv-*/`

6. **Verify**: `nix develop --command bash -c 'cargo check --manifest-path src-tauri/Cargo.toml'` and `--features desktop-player` both green; Windows vendor flow: place zip from `Stremio/stremio-shell-ng` releases at `src-tauri/libmpv-2_x64.zip` → `cargo tauri build --features desktop-player` links vendored lib.

## Pitfalls
- `pkgs.mpv.dev` missing attr on some nixpkgs → use `${pkgs.mpv}/lib/pkgconfig`
- `zip-extract` cfg needs feature `zip-extract` declared else `unexpected_cfgs` warning
- `mut` on `event_loop(client: Mpv,...)` not needed
