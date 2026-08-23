---
name: safe-worktree-cleanup
description: Safely clean up completed Git worktrees after issue-linked PRs merge
---

1. Confirm the issue-linked changes are committed, pushed, and represented by a pull request.
2. Confirm the PR is merged before deleting its branch.
3. From a different checkout, run `git worktree remove <worktree-path>`.
4. Run `git branch -d <branch-name>`; never force-delete unmerged work.
5. Verify with `git worktree list` and `git branch --list <branch-name>`.
6. If uncommitted changes or unmerged work blocks cleanup, preserve the worktree and report the blocker.
