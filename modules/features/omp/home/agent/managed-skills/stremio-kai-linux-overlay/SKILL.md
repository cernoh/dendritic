---
name: stremio-kai-linux-overlay
description: Package Stremio-Kai portable mpv configuration for Linux in a Nix flake
---

Use the validated procedure: pin portable_config-only source, package with an overlay, deliver through a `stremio-mpv` wrapper that scopes mpv config via MPV_HOME to a writable home dir, and verify syntax/evaluation/build. Do not copy into the user's live `~/.config/mpv` (issue #99: the old activation clobbered personal mpv settings).

## Layout

- `modules/features/stremio-kai/_stremio-kai.pkg.nix` — plain data derivation (no build step), `cp -r portable_config $out/share/stremio-kai/portable_config`.
- `modules/features/stremio-kai/default.nix` — HM feature delivering:
  - the data package + a `stremio-mpv` `writeShellScriptBin` wrapper
  - the wrapper sets `MPV_HOME=$HOME/.local/share/stremio-kai-mpv` and `exec`s
    `mpv "$@"`; first run (or a package change, stamped by store path in
    `.stremio-kai-rev`) `cp -r`s the portable_config tree there and `chmod -R
    u+w`; the dir stays writable so the Lua scripts' `track_preferences.json`
    persistence works.

## Wiring

- Point Stremio's player at the wrapper: Settings → Advanced → player →
  custom path `stremio-mpv` (PATH-visible via home.packages).
- mpv itself ships from the nixpcDesktop feature (#25).

## Verification

- Syntax/eval: `nix-instantiate --parse modules/features/stremio-kai/default.nix`;
  eval the wrapper out: `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.packages` contains `stremio-mpv`.
- Smoke (NIXPC): `stremio-mpv --version`; confirm `stremio-mpv --no-config "${stremio-kai}/share/stremio-kai/portable_config"`-style playback loads the Kai tree by checking `$HOME/.local/share/stremio-kai-mpv/scripts` exists and `~/.config/mpv` was never touched.

When a fix appears uncommitted, check HEAD and the remote branch before retrying commit; it may already be included in an earlier commit.