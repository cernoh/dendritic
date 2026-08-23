---
name: nix-modules-and-options
description: "Safely edit NixOS and Home Manager modules by tracing option types, merge semantics, and platform scope"
---

# Nix modules and options

Use for NixOS, Darwin, and Home Manager module changes.

## Rules
- Find the option declaration and current callsites before editing.
- Respect module merge semantics: lists, attribute sets, priorities, and definitions do not all combine the same way.
- Do not guess option names or types from memory. Query the evaluated option set or read the declaration.
- Keep host-specific settings in host modules; keep shared settings platform-neutral.
- Do not use `lib.mkForce` or `lib.mkDefault` until ordinary definitions and the conflict are understood.

## Procedure
1. Identify the target configuration output and its system.
2. Locate the option declaration and existing definitions.
3. Make the smallest definition that expresses the desired merge behavior.
4. Run the narrowest evaluator: `nixos-rebuild dry-build --flake .#<host>`, `darwin-rebuild check --flake .#<host>`, or `home-manager build --flake .#<user>`.
5. Inspect the resulting activation/config artifact when behavior depends on generated files.

## Checks
- Undefined option versus invalid value are different failures.
- A successful evaluation does not prove activation or runtime behavior.
- Check assertions and warnings; do not suppress them to get a green command.

## Renewal
Option names and types follow the selected nixpkgs/Home Manager revision. Re-check declarations after input updates.
