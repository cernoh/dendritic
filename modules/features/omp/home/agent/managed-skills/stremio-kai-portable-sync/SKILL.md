---
name: stremio-kai-portable-sync
description: Sync Stremio-Kai portable_config upstream into stremio-accru worktree
---

# Stremio-Kai Portable Sync

Use when syncing https://github.com/allecsc/Stremio-Kai/tree/main/portable_config into stremio-accru's `portable_config/`.

## Procedure
1. Create isolated worktree: `git worktree add -b feat/kai-config-sync /mnt/2tb-storage/stremio-accru-kai HEAD` — never edit default branch directly.
2. Fetch real upstream files via `gh api repos/allecsc/Stremio-Kai/contents/portable_config/<path> --jq '.content' | base64 -d` — do not assume from docs/PLAN.md. Required paths:
   - `mpv.conf`, `input.conf`, `stremio-settings.ini`
   - `script-opts/{notify_skip,smart_track_selector,svp,thumbfast,stats}.conf`
   - `scripts/{profile-manager.lua,thumbfast.lua,svp_cleanup.lua,reactive_vf_bypass.lua}`
   - `scripts/notify_skip/{main.lua,modules/*.lua}` (10 modules), `scripts/smart-track-selector/{main.lua,track_preferences.json}`
   - `svp_anime.vpy`, `svp_cinema.vpy` (create `svp_main.vpy` alias to svp_anime for F12 `~~/svp_main.vpy`)
3. Write verbatim with Accru header; patch cross-platform:
   - `thumbfast.conf:mpv_path=portable_config/mpv/mpv.exe` → comment out `#mpv_path=auto`, keep commented original.
4. Shaders: `portable_config/shaders/` is empty in Kai git. Fetch 19 Anime4K GLSL from `bloc97/Anime4K` raw `glsl/{Restore,Upscale,Upscale+Denoise,Experimental-Effects}`. Fetch community shaders that Ace stubs as placeholders:
   - `nlmeans.glsl` + `hdeband.glsl` + `denoise1/2/3.glsl` + `sharpen_denoise.glsl` from `AN3223/dotfiles/.config/mpv/shaders` (nlmeans variants)
   - `adaptive-sharpen.glsl` from `deus0ww/mpv-conf/shaders/igv/adaptive-sharpen.glsl` (igv)
   Do NOT leave no-op `void main(){}` stubs — `filter_existing_shaders` would treat them as present and silently skip real denoising.
5. Patch `scripts/profile-manager.lua` for graceful degrade:
   - Add `file_exists()` via `mp.command_native({"expand-path", path})` + `utils.file_info`
   - Add `filter_existing_shaders(chain)` to drop missing tokens before `mp.set_property("glsl-shaders", ...)`
   - Guard both SVP appends (anime `svp_anime` and cinema `svp_cinema`) with `file_exists` check.
6. Verify: `portable_config` tree = 27 shaders / 3 vpy / 5 script-opts / 6 lua + modules. `tauri.conf.json` already bundles `resources: ["../portable_config"]`.
7. Commit with `Closes #N`, push worktree branch, open PR `feat/kai-config-sync → main` with provenance.
