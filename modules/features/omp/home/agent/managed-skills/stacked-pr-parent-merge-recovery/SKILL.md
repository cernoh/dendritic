---
name: stacked-pr-parent-merge-recovery
description: "Recover a stacked PR chain when merging the parent with --delete-branch auto-closes the child PR: reopen refuses, retarget refuses, so rebase the child onto main (duplicate commit auto-skipped), force-push, and open a fresh PR against main; includes the pre-prune content checks. Use when a child PR of a stack shows CLOSED right after the parent merged."
---

Verified 2026-09-15 on `cernoh/dendritic` (squash merges, stacked PRs, no worktrees).

## The trap

`gh pr merge <parent> --squash --delete-branch` deletes the branch the child PR targets. GitHub then **closes the child PR** about 2 seconds later, with `mergedAt: null` and `closedAt` set.

```
gh pr view <child> --json state,baseRefName,mergedAt,closedAt
# {"state":"CLOSED","baseRefName":"feat/<parent>","mergedAt":null,"closedAt":"..."}
```

Both recovery APIs refuse, because the base ref no longer exists:

- `gh pr reopen <child>` → `GraphQL: Could not open the pull request. (reopenPullRequest)`
- `gh pr edit <child> --base main` → `GraphQL: Cannot change the base branch of a closed pull request. (updatePullRequest)`

## Recovery: replace the child PR

1. Rebase the child onto the squashed parent. `--autostash` handles a dirty tracked file (for example a home-manager-written `config.yml`) without a manual stash:

   ```
   git fetch origin
   git checkout feat/<child>
   git rebase --autostash origin/main
   # warning: skipped previously applied commit <sha>   <- the squashed parent, expected
   ```

2. Force-push with lease, then open a **fresh** PR against `main` from the same head branch. Say in the body that it supersedes the auto-closed PR, and keep `Closes #<child-issue>`.

3. The closing keyword only works against the default branch: GitHub reported `closingIssuesReferences: []` while the child targeted `feat/<parent>`, and `[<issue>]` once the base was `main`. Expect the child issue to stay open until the replacement PR merges to `main`.

## Pre-prune content checks

A squash merge leaves the branch tip unrelated to `main`, so `git branch -d` refuses. Prove the content is on `main` before `git branch -D`:

```
git diff --stat origin/main feat/<child>          # empty = identical trees
git diff --stat --diff-filter=D feat/<child> origin/main   # empty = nothing lost
```

Run these *before* deleting. Then `git branch -D`, and confirm with `git branch --list` / `git worktree list`.

## Prevention

Omit `--delete-branch` on a parent whose child PR is still open, or retarget the child to `main` first. Deleting the parent branch after the child merges is safe.
