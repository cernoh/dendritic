---
name: jj-resolve-branches-to-main
description: Clean up merged feature branches into a single main tree in a jj + git colocated repository.
---

# Resolve branches into a single main tree

Use this when a feature branch has already been merged into `main` and you need to clean up the remaining worktrees, local branches, bookmarks, and remote branches.

## Check state

```bash
jj status
jj bookmark list
jj log -r 'all()' --limit 20
git worktree list
git branch -a
```

## Clean up dangling / WIP commits

Abandon any conflict or empty continuation commits, including the current working copy if it is an empty child of main:

```bash
jj abandon <conflict-wip-rev>
jj abandon <empty-continue-rev>
```

In jj, abandoning the current working copy creates a new empty working copy on the same parent. Repeat if needed until you are on the desired parent.

## Remove worktrees

```bash
git worktree remove .worktrees/<branch-name>
```

Repeat for each merged worktree.

## Delete local branches

```bash
git branch -D <branch-name>
```

If the repo is colocated, jj will import the deletion and remove the matching bookmark automatically.

## Re-attach git HEAD

```bash
git checkout main
```

## Delete remote branches (optional)

If the branch is fully merged and no longer needed:

```bash
git push origin --delete <branch-name>
```

## Verify

```bash
jj status
jj bookmark list
git branch -a
git status
```

## Notes

- `jj edit main` may fail with "immutable commit" because the remote bookmark makes the main commit immutable. In that case, use `jj abandon` on the current empty working-copy commit instead.
- Remove empty `.worktrees/` directories after the worktrees are removed so they do not appear as untracked files.
