---
name: nixpc-nixos-host-verification
description: "Verify a newly added nixpc NixOS host with MangoWM, Noctalia, and tuigreet"
---

1. Confirm the host uses the established `davr` user identity.
2. Define target-specific `fileSystems."/"` and `fileSystems."/boot"` or import generated hardware configuration before evaluating.
3. Evaluate `nix eval '.#nixosConfigurations.nixpc.config.system.build.toplevel.drvPath'`.
4. Evaluate `programs.noctalia.package.pname` and `programs.noctalia.systemd.enable` under the nixpc Home Manager user.
5. Treat successful option evaluation as distinct from deployability: replace placeholder disk labels with hardware-specific values before installation.
