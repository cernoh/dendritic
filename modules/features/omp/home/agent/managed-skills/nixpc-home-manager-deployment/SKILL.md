---
name: nixpc-home-manager-deployment
description: Deploy or diagnose the nixpc Home Manager target in home-manager-v3
---

## Procedure

1. Confirm the target exists as `homeConfigurations.nixpc` and, for a full NixOS deployment, `nixosConfigurations.nixpc`.
2. Use the required flake syntax:
   ```bash
   home-manager switch --flake ~/.config/home-manager-v3#nixpc -b backup
   ```
   Do not pass `.#nixpc` or `/path#nixpc` as a positional argument.
3. For the complete host configuration, use:
   ```bash
   sudo nixos-rebuild switch --flake ~/.config/home-manager-v3#nixpc
   ```
4. Verify the Home Manager target with:
   ```bash
   nix eval --json '.#homeConfigurations.nixpc.config.wayland.windowManager.mango.enable'
   nix eval --raw '.#homeConfigurations.nixpc.activationPackage.drvPath'
   ```
5. Build the generated Mango configuration separately if the full activation build is slow:
   ```bash
   nix eval --raw '.#homeConfigurations.nixpc.config.xdg.configFile."mango/config.conf".source'
   nix-store --query --deriver <source-path>
   nix build <derivation-path> --no-link
   ```
6. The current locked MangoWM input rejects `scroll_method`; remove it from `config/mango.nix` when the generated config fails with `Unknown keyword: scroll_method`.
