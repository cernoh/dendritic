---
name: nix-flake-maintenance
description: "Safely inspect, validate, update, and roll back Nix flakes and lock files"
---

# Nix flake maintenance

Use for routine flake changes, input updates, and lock-file hygiene.

## Rules
- Read `flake.nix`, `.envrc`, and repository instructions before editing.
- Check the current branch; never edit the default branch. Use a worktree when the repository is GitHub-oriented.
- Prefer the smallest input or output change. Do not update unrelated inputs.
- Never hand-edit `flake.lock`; use `nix flake lock`, `nix flake update`, or `nix flake update <input>`.
- Keep the lock file committed unless the repository explicitly says otherwise.

## Procedure
1. Establish baseline: `nix flake check --show-trace`.
2. Inspect inputs: `nix flake metadata` and `nix flake show`.
3. Update only the requested input: `nix flake update <input>`.
4. Re-run `nix flake check --show-trace`.
5. Exercise the affected output (`nix build`, `nix develop`, or a dry-run switch).
6. Review `git diff -- flake.nix flake.lock`; revert unrelated lock churn.

## Verification
Record the exact commands and output. If validation needs network access, say so. If an update breaks evaluation, revert the lock change before investigating further.

## Renewal
Nix CLI behavior and nixpkgs attributes change. Before using this skill on a new class of output, verify command syntax with `nix --help` and current Nix documentation; preserve only commands that still work.
