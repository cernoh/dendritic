---
name: nixpc-noctalia-greeter
description: Add and verify Noctalia Greeter as the greetd login session for the nixpc NixOS host
---

# nixpc Noctalia Greeter

Use this procedure when replacing the nixpc greetd login UI with Noctalia Greeter in `home-manager-v3`.

## Implementation

1. Add the input to `flake.nix`:
   ```nix
   noctalia-greeter = {
     url = "github:noctalia-dev/noctalia-greeter";
     inputs.nixpkgs.follows = "nixpkgs";
   };
   ```
2. Pass `noctalia-greeter` into the `nixosConfigurations.nixpc` import.
3. In `flake/nixpc-nixos.nix`, add `noctalia-greeter` to the function arguments and import `noctalia-greeter.nixosModules.default`.
4. Enable the module in the nixpc system configuration:
   ```nix
   programs.noctalia-greeter = {
     enable = true;
     greeter-args = "--session Mango";
   };
   services.greetd.settings.default_session.user = "davr";
   ```
5. Remove the old explicit Tuigreet command and input from the nixpc path. The Noctalia Greeter module supplies the greetd command and package.
6. Keep the greeter system-scoped. Do not add the NixOS greeter module to the standalone Home Manager `homeConfigurations.nixpc` output.
7. Lock the new input with:
   ```bash
   nix flake lock --update-input noctalia-greeter
   ```

## Configuration facts

- The module writes the greetd command as `<package>/bin/noctalia-greeter-session -- <greeter-args>`.
- `--session` expects the desktop-entry `Name=` value. Mango's current desktop entry uses `Name=Mango`, so use `--session Mango`.
- The module enables greetd and `services.accounts-daemon` by default, creates `/var/lib/noctalia-greeter`, and installs the greeter package.
- Declarative greeter settings belong under `programs.noctalia-greeter.settings`; mutable shell sync data is separate.

## Verification

Run these focused checks:

```bash
nix eval --json '.#nixosConfigurations.nixpc.config.programs."noctalia-greeter".enable'
nix eval --raw '.#nixosConfigurations.nixpc.config.services.greetd.settings.default_session.command'
nix eval --raw '.#nixosConfigurations.nixpc.config.system.build.toplevel.drvPath'
nix build '.#nixosConfigurations.nixpc.config.programs."noctalia-greeter".package' --no-link
```

The expected command contains `noctalia-greeter-session -- --session Mango` and the expected user is `davr`.

A full system build may be blocked by unrelated upstream download or substituter failures. Distinguish that infrastructure failure from successful option evaluation and greeter-package compilation. Activate only after reviewing the generated greetd configuration:

```bash
sudo nixos-rebuild switch --flake ~/.config/home-manager-v3#nixpc
```
