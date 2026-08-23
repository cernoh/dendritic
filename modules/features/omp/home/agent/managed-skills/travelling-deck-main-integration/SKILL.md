---
name: travelling-deck-main-integration
description: Merge travelling-deck Worktrunk branches into main and verify the integrated repository
---

## Procedure

1. From the repository root, run `wt list`.
2. In each feature worktree, run `wt step diff` and `git status --short --branch`; identify whether the branch has unique commits or uncommitted changes.
3. From the main checkout, merge each intended branch explicitly. If a branch is already an ancestor, record that no merge is needed.
4. Remove merged worktrees with `wt remove -y` from each worktree, then confirm only main remains with `wt list`.
5. Run the project gates from main:
   - `nix develop --command bash -lc 'PYTHONPATH=backend:. python -m unittest discover -s backend/tests -t .'
   - `cd frontend && npm ci && node --test --experimental-strip-types src/horizon.test.ts && npm exec -- tsc --noEmit`
   - `nix flake check`
6. Require clean status and synchronize main with `git push origin main`.
7. Confirm `git status --short --branch`, `wt list`, and `git ls-remote --heads origin main` agree on the final main commit.
