---
name: nix-reproducibility-and-secrets
description: "Keep Nix builds reproducible while handling secrets, impurity, fixed outputs, and system-specific inputs safely"
---

# Nix reproducibility and secrets

Use when a flake depends on credentials, generated files, network access, or multiple machines.

## Rules
- Never put secrets in `flake.nix`, `flake.lock`, derivation arguments, or tracked generated output.
- Treat `--impure`, `builtins.getEnv`, timestamps, home-directory reads, and network fetches as explicit reproducibility boundaries.
- Prefer content-addressed or fixed-output fetchers with hashes; do not replace a missing hash with a fake value.
- Keep machine- and user-specific data outside shared pure expressions when possible.

## Procedure
1. Identify every input: tracked files, flake inputs, environment, credentials, network, host platform.
2. Make evaluation pure by default; use an explicit, documented escape hatch only when required.
3. Validate with a clean checkout and the exact target system.
4. Confirm secrets are absent from `nix flake metadata`, diffs, store paths, logs, and build products.
5. Pin dependencies and review lock changes narrowly.

## Checks
A build that works only with a developer's environment is not reproducible. A secret that reaches `/nix/store` is compromised; rotate it, remove the reference, and rebuild cleanly.

## Renewal
Re-check Nix's current purity, fetcher, and content-addressing guidance before adopting new experimental features.
