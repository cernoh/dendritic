---
name: worktrunk-feature-workflow
description: Create isolated feature branches in GitHub repositories using Worktrunk
---

1. Check current worktrees with `wt list`.
2. Create a feature worktree with `wt switch --create <branch>` from the default branch.
3. Work inside the resulting `.worktrees/<branch>` directory.
4. Verify with the narrow project build/test commands.
5. Use `wt list` and `wt step diff` before handoff or merge.
