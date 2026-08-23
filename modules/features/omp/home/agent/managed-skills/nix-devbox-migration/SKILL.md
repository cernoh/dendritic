---
name: nix-devbox-migration
description: Migrate a project from devbox to a simple Nix flake dev shell
---

# Migrate devbox → Nix flake dev shell

## When to use
A project currently uses `devbox.json` and you want to replace it with a plain `nix develop` flake.

## Steps
1. Read `devbox.json` and note the packages.
2. Work in a feature branch (or worktree for GitHub repos).
3. Create `flake.nix` with a `devShell` using `mkShell` and the equivalent packages.
4. Update `.envrc` to `use flake` (requires nix-direnv).
5. Stage new files (`git add flake.nix`) before running `nix develop` so Nix can see them.
6. Test the shell and the project:
   ```sh
   nix develop --command bash -c 'bun --version && tsc --version && prettierd --version'
   nix develop --command bash -c 'bun install && bun run build'
   ```
7. Update any devbox-specific docs/agent configs (e.g. `.github/agents/devbox.yml` → `nix.yml`).
8. Remove `devbox.json`, `devbox.lock`, and ignore `.devbox/` in `.gitignore`.
9. Commit, push, and open a PR.

## Common nixpkgs package-name changes
- `nodePackages.typescript` → `typescript` (top-level)
- `nodePackages.prettierd` → `prettierd` (top-level)
- Recent nixpkgs unstable removed `nodePackages` entirely; prefer top-level attributes.

## Verification
Always confirm the project still builds inside the new shell after migration. If a test step updates the package lock file (e.g. `bun.lockb`), restore it to avoid unintended dependency changes.
