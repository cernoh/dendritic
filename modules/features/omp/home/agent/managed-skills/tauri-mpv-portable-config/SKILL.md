---
name: tauri-mpv-portable-config
description: "Wire Tauri libmpv config-dir so ~ resolves to portable_config (mpv.conf, scripts, shaders)"
---

# Tauri MPV Portable Config

Fix `~~` not resolving when using libmpv2 in Tauri with a Kai-style `portable_config/` overlay.

## Symptom
`create_mpv` only sets `vo`/`hwdec`; `mpv.conf`/`input.conf`/`scripts/*.lua`/`script-opts/*`/`~~/shaders/*.glsl` never load. `thumbfast.lua` + `profile-manager.lua` fail. `portable.rs` only checks `is_portable`.

## Fix

### 1. `src-tauri/src/config/portable.rs` — add helper
```rust
pub fn portable_config_dir(app: &AppHandle) -> PathBuf {
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            let sibling = dir.join("portable_config");
            if sibling.exists() { return sibling; } // portable extract-and-play
        }
    }
    if let Ok(res) = app.path().resource_dir() {
        return res.join("portable_config"); // bundled via tauri.conf.json resources
    }
    dirs::data_dir().map(|b| b.join("stremio-accru").join("portable_config"))
        .unwrap_or_else(|| PathBuf::from("portable_config"))
}
```
Fix `unwrap_or_else(|| ...)` (Option takes 0 args) and ensure `pub fn data_dir` has no leading space — `cargo fmt` will flag.

### 2. `src-tauri/src/player/desktop.rs` — set before vo/hwdec
Change signature to `fn create_mpv(app: &AppHandle, wid: Option<i64>)` and at top of `with_initializer`:
```rust
{
    let cfg = crate::config::portable::portable_config_dir(app);
    if cfg.exists() {
        let s = cfg.to_string_lossy().to_string();
        let _ = init.set_property("config", "yes");
        let _ = init.set_property("config-dir", s.as_str());
        tracing::info!(target: "player", "mpv config-dir={s} (~~ resolves here)");
    }
}
```
Update `ensure_mpv` to `create_mpv(&self.app, wid)`.

### 3. `src-tauri/tauri.conf.json`
Ensure `"resources": ["../portable_config"]` so shaders/scripts bundle and `resource_dir/portable_config` exists in dev/build.

## Verify
```bash
nix develop --command cargo check --manifest-path src-tauri/Cargo.toml --features desktop-player
nix develop --command cargo test --manifest-path src-tauri/Cargo.toml  # 44 passed
nix develop --command bash -c "cargo fmt --manifest-path src-tauri/Cargo.toml --check"
```
`~~/shaders` should count 27 glsl + svp_*.vpy; `profile-manager.lua` filters missing gracefully.
