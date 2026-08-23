---
name: asahi-driftwm-wallpaper-fix
description: Diagnose and fix drifting-antiquity wallpaper path failures in Asahi home-manager configurations
---

## Procedure

1. Inspect the upstream drifting-antiquity module for its `theme.wallpaperDir` default.
2. If it defaults to an absent `flake/wallpapers` path, override it in `config/asahi-config.nix` with an existing source path such as `./swaybg`.
3. If wallpapers are managed independently, set `theme.autostart.wallpaper = false`.
4. Verify with `nix eval --extra-experimental-features 'nix-command flakes' --raw '.#homeConfigurations.asahi.activationPackage.drvPath'` and `home-manager build --flake .#asahi --no-out-link --extra-experimental-features 'nix-command flakes'`.
