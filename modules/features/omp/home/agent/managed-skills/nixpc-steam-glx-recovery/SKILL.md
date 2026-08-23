---
name: nixpc-steam-glx-recovery
description: Diagnose and verify Steam glXChooseVisual crashes on the nixpc NixOS Wayland host before and after activation
---

# nixpc Steam GLX recovery

Use this procedure when Steam on nixpc exits with `glXChooseVisual failed` and `Fatal assert; application exiting`.

## Root cause to check

The NixOS `programs.steam` module enables Steam's required 32-bit graphics support and adds system graphics libraries to Steam's pressure-vessel environment. Installing `pkgs.steam` only through Home Manager does not enable those NixOS integrations.

## Configuration

1. In the nixpc NixOS module, enable:
   ```nix
   programs.steam.enable = true;
   ```
2. Remove duplicate `steam` from the nixpc Home Manager `home.packages` list.
3. Preserve Wayland-first behavior while allowing Xwayland fallback:
   ```nix
   SDL_VIDEODRIVER = "wayland,x11";
   ```

## Verification before activation

1. Evaluate the target:
   ```bash
   nix eval --impure --json '.#nixosConfigurations.nixpc.config.programs.steam.enable'
   nix eval --impure --json '.#nixosConfigurations.nixpc.config.hardware.graphics.enable32Bit'
   nix eval --impure --raw '.#homeConfigurations.nixpc.config.home.sessionVariables.SDL_VIDEODRIVER'
   ```
   Expected values: `true`, `true`, and `wayland,x11`.
2. Parse changed Nix files with `nix-instantiate --parse`.
3. Inspect the exact evaluated Steam rootfs derivation. Its derivation inputs/`paths32` must include the NVIDIA `lib32` output and graphics libraries. Do not infer this from an unrelated existing Steam store path.
4. Locate the exact evaluated wrapper path. A store path from an older generation is not valid evidence.
5. Execute the exact new wrapper in the active Wayland session with `SDL_VIDEODRIVER=wayland,x11`, then inspect the timestamped tail of `~/.local/share/Steam/logs/console-linux.txt` for the absence of `glXChooseVisual failed` and `Fatal assert`.

## Important failure mode

A full Nix build may fail before producing the intended wrapper because of unrelated upstream source downloads or fixed-output dependency failures. In that case, report the runtime test as blocked. If an already-built wrapper still reproduces the crash, first confirm whether its derivation contains the new NVIDIA `lib32` inputs; otherwise it is not a test of the fix.

## Activation

After the intended output is built:
```bash
sudo nixos-rebuild switch --flake ~/.config/home-manager-v3#nixpc
```
Log out and back in so the session variables are refreshed, then launch Steam normally.
