---
name: nixpc-mangowm-host
description: "Create or extend an x86_64 Linux gaming Home Manager host with MangoWM in home-manager-v3, including verified cross-monitor window hotkeys"
---

## Procedure

1. Add `mangowm = { url = "github:DreamMaoMao/mangowc"; inputs.nixpkgs.follows = "nixpkgs"; };` to flake inputs.
2. Define `mangowmOverlay = final: _prev: { mangowm = mangowm.packages.${final.stdenv.hostPlatform.system}.mango; };` and include it in `nixpkgs.overlays`.
3. Expose `overlays.mangowm = mangowmOverlay`.
4. In the host Home Manager module, extend `nixpkgs.legacyPackages.x86_64-linux` with `mangowm.overlays.default`, import `mangowm.hmModules.mango`, and import the host config plus shared `home.nix`.
5. Keep Nvidia/session variables and gaming packages host-specific.
6. For a hotkey that moves the focused window to the monitor on the right, add a string such as `"SUPER+SHIFT,M,tagmon,right,1"` to the Mango `bind` list. `tagmon` moves the focused client; the final `1` preserves/applies the current tag set. Existing directional bindings can use `tagmon,left/right` for relative movement.
7. Keep Nix comments outside generated binding lists. Home Manager's Mango renderer emits every list element as a config line; an inline comment becomes invalid Mango syntax.

## Verification

- Run `nix eval --json '.#homeConfigurations.nixpc.config.wayland.windowManager.mango.enable'`.
- Run `nix-instantiate --parse config/mango.nix`.
- Run `home-manager build --flake .#nixpc --no-out-link`; this exercises Mango's config validation.
- Inspect the generated Mango config and confirm the emitted line is `bind = SUPER+SHIFT,M,tagmon,right,1`.

## Packaging boundary

Do not package Stremio-Kai for Linux. Its upstream repository is Windows-only and has no Linux source or artifact. Use `stremio-linux-shell` from nixpkgs when Linux Stremio support is needed.
