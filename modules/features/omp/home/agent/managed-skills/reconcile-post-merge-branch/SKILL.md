---
name: reconcile-post-merge-branch
description: Use when follow-up commits exist on a feature branch after its GitHub PR was merged.
---

## Reconcile post-merge commits

1. Fetch `origin/main`.
2. Confirm the PR merge commit is on `origin/main` and follow-up commits are only on the feature branch.
3. Work from a checkout based on `origin/main`.
4. Merge the feature branch with a real merge, not `--ff-only`, so the post-merge commits are reconciled with the remote merge commit.
5. Push the resulting main branch.

This avoids non-fast-forward failures when the feature branch predates the PR merge commit.
