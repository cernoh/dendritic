---
name: git-intent-to-add-pull-blocker
description: "Fix git pull/git merge failing with \"Entry 'X' not uptodate. Cannot merge.\" + \"fatal: stash failed\" when the index holds git add -N intent-to-add entries; includes the trap that plain git add does NOT fix it and stages artifacts."
---

# `git pull` blocked by intent-to-add entries

Apply when a divergent `git pull` or `git merge` refuses with this pair:

```
error: Entry 'path/to/file' not uptodate. Cannot merge.
Cannot save the current worktree state
fatal: stash failed
```

## Cause

The index holds **intent-to-add** entries from `git add -N` / `git add --intent-to-add`
(often from a `git add -N .` sweep). An i-t-a entry stores the **empty blob**
`e69de29bb2d1d6434b8b29ae775ad8c2e48c5391` while the worktree file has real content.

`git pull` autostashes by default (git >= 2.27) and that autostash runs `git stash push`,
which refuses i-t-a entries. The merge never starts.

This is **not** stat-dirty state, not `core.fsmonitor`, not a custom hook, and not
`merge.autostash` — the setting is empty by default and pull still stashes.

## Diagnose

```bash
# i-t-a entries: empty blob in the index. NOTE a genuinely tracked empty file
# also shows e69de29b, so cross-check the next command.
git ls-files -s | awk '$2=="e69de29bb2d1d6434b8b29ae775ad8c2e48c5391" {print $4}'

# the real i-t-a set: pending added paths (status shows " A", not "A ")
git diff --name-only --diff-filter=A
```

## Fix

```bash
git diff --name-only --diff-filter=A > /tmp/ita-paths.txt   # record first
git status --porcelain > /tmp/status-before.txt             # to diff afterwards

git update-index --force-remove -- $(cat /tmp/ita-paths.txt)
git pull                                                    # now succeeds

# restore the marks the user intended (files never left disk)
git add -N -- $(cat /tmp/ita-paths.txt)
diff <(sort /tmp/status-before.txt) <(git status --porcelain | sort)
```

Index-only removal: file contents are untouched. Prefer this over `git stash`, which fails.

## Trap

**Do not "fix" it with `git add <path>`.** Verified on git 2.34.8, that fails instead:

```
error: Your local changes to the following files would be overwritten by merge:
Merge with strategy ort failed.        # exit 2
```

and it stages the artifact, so an inattentive `git commit` ships it. Clearing the i-t-a
mark is the only step that unblocks the pull.

## Reproducing in a scratch repo

Faithful harness, in this order (order matters):

1. bare remote + clone `up`; commit and push a base.
2. clone `work`; **diverge** (commit locally).
3. create the artifact file; `git add -N <file>`.
4. **only now** advance `up` and push (if upstream moves before cloning, every probe
   prints a vacuous `Already up to date`).
5. `git pull` reproduces the pair. Isolate the layer with a direct `git stash push`,
   which fails on its own.

`git -c merge.autostash=false merge` is not a valid control unless you `git fetch` first.

## Adjacent hygiene

Python `__pycache__/` artifacts get swept into i-t-a by a blanket `git add -N .` and
re-dirtied by any later interpreter run. Add `__pycache__/` to `.gitignore`.
