---
name: nix-system-deployment
description: "Select, build, activate, and verify the correct NixOS, Darwin, or Home Manager system output"
---

# Nix system deployment

Use when changing or applying a NixOS, nix-darwin, or Home Manager configuration.

## Rules
- Name the exact flake output and target system before running a command.
- Do not use a generic `.#default` when the repository exposes host-specific outputs.
- Separate dry-build/check, build, and activation. Activation is the only step that changes the machine.
- Never apply a configuration to a host you have not identified from the flake outputs.

## Procedure
1. Inspect outputs: `nix flake show`.
2. Validate the target: `nixos-rebuild dry-build --flake .#<host>`; use the platform's equivalent for Darwin/Home Manager.
3. Build first when practical and inspect the result.
4. Activate only with the explicit target and requested mode (`switch`, `boot`, or `test`).
5. Verify the changed behavior on the live system and retain the generation rollback path.

## Checks
- Confirm `system`, hostname, user, and architecture agree.
- Check activation warnings and failed units, not only exit status.
- If activation partially changes state, use the system's generation rollback rather than ad hoc deletion.

## Renewal
Command names and platform workflows vary. Confirm current flags with the installed rebuild command's `--help`.
