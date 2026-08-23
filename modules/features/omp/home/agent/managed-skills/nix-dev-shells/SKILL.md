---
name: nix-dev-shells
description: Design and verify minimal reproducible development shells from flake outputs
---

# Nix development shells

Use when adding or repairing `devShells` and `.envrc` behavior.

## Rules
- Put tools in the flake, not in undocumented host setup.
- Use `pkgs.mkShell` and existing inputs; do not add a framework for shell hooks.
- Keep `packages` and `nativeBuildInputs` minimal and platform-aware.
- Do not mutate project files from shell hooks unless explicitly required.

## Procedure
1. Identify supported systems and the project commands that must run.
2. Define `devShells.<system>.default` with only required packages and a short `shellHook` if needed.
3. Keep `.envrc` to `use flake` (or the repository's established equivalent).
4. Test without an interactive shell:
   `nix develop .#default --command bash -lc 'command -v <tool> && <project-check>'`.
5. Test the declared system explicitly when cross-platform behavior matters.

## Failure boundaries
- `nix develop` evaluation failure: fix flake syntax, inputs, or package attributes.
- Missing command: fix the shell package list.
- Project failure inside the shell: fix project dependencies, not the shell with ad hoc global installs.
- direnv-only failure: verify direnv/nix-direnv separately from Nix.

## Renewal
Refresh package names against current nixpkgs before copying examples. Prefer stable package attributes and verify with `nix search nixpkgs <name>`.
