---
name: omp-flake-version-update
description: "Update oh-my-pi (omp) via the overlay — refresh the oh-my-pi flake input, verify overlay and tooling"
---

# Update OMP via overlay

Upstream `can1357/oh-my-pi` is consumed as a flake input `oh-my-pi` with its
overlay re-exported as `overlays.omp` / `overlays.default` (see
`modules/features/omp/default.nix`). No vendored binary hashes live in
`flake.nix`; updates are a lock refresh.

## When to use
User asks to update oh-my-pi / omp, bump the flake, or refresh tooling.

## Procedure

1. **Update the input** (pull latest upstream rev):
   ```bash
   nix flake update oh-my-pi
   # or pin to a rev:
   # nix flake lock --update-input oh-my-pi
   ```

2. **Verify overlay and package**:
   ```bash
   nix flake show --impure | grep -E "overlays|omp"
   nix eval --impure .#packages.x86_64-linux.omp.version
   nix eval --impure .#packages.aarch64-linux.omp.version
   nix eval --impure .#overlays.omp --apply "x: builtins.typeOf x"
   ```

3. **Verify tooling fronts** (devShell, app, modules):
   ```bash
   nix eval --impure .#apps.x86_64-linux.omp.type
   nix eval --impure .#devShells.x86_64-linux.omp.name
   nix flake check --impure --show-trace  # optional: heavy, builds checks
   ```

4. **Commit** `flake.lock` (and any `flake.nix` follow tweaks if needed).

## Notes
- No SHA256 hashes to convert — upstream builds from source via `nix/package.nix`
  (Rust + Bun) through the overlay, not prebuilt binaries.
- The old `cernoh/omp-flake` binary-flake workflow (curl GitHub API, hex→SRI,
  edit `sources` attrset) is obsolete; do not use it.
- Windows binary exists upstream but is not a Nix target.
