---
name: git-repo-to-jj-colocated-conversion
description: "Convert an existing git repository (dirty tree, feature branches, GitHub remote) to a colocated jj repo: jj git init --colocate, track origin bookmarks, verify git interop stays intact. Use when the user says \"convert this to use jj instead of git\" or wants to start managing an existing git checkout with jj."
---

# Git repo → colocated jj conversion

Convert an existing git repo with remotes to Jujutsu while keeping git fully functional (GitHub CI, gh CLI, pushes). Colocated is the correct default whenever the repo has a remote that other tooling touches. Verified on jj 0.44.0, dendritic repo (2026-09-02).

## Before

- `git status --porcelain`, `git branch -vv`, `git worktree list` — note dirty state and all local branches so you can verify preservation.
- Untracked files become part of `@` (working copy) after init; they stay uncommitted.

## Procedure

Run INSIDE the repo directory — `jj git init` takes no `-R`/`--repository` flag and fails with "There is no jj repo" if pointed at an existing repo via `-R`:

```bash
jj git init --colocate
```

`--colocate` is the default unless config says otherwise; `.jj/` self-ignores via generated `.jj/.gitignore` (`/*`) — verify: `git status --porcelain` must NOT list `.jj/`.

Init output:
- Imports all git branches as local bookmarks; origin refs become remote-tracking bookmarks; `trunk()` revset aliased to `main@origin`.
- Prints a hint listing remote bookmarks "not associated with existing local bookmarks" — run the exact suggested command to make fetch/push sync them:

```bash
jj bookmark track <name>@origin ... main@origin
```

Only bookmarks you track advance local bookmarks on `jj git fetch`; untracked ones stay stale. Tracked status shows in `jj bookmark list` (local names listed without trailing `@origin` markers do not indicate tracking — use the hint command).

## Verify

- `jj st` — working-copy diff equals the pre-conversion `git status` dirty set.
- `jj log -r 'main::@'` — `@` is a working-copy change on top of main; nothing committed.
- `git status`/`git log` still work and show identical state; `git branch --show-current` still `main`.
- `jj bookmark track` output: "Started tracking N remote bookmarks."

## After

Daily flow: `jj st`, `jj new`, `jj desc -m "…"`, `jj git fetch`, `jj git push -b <bookmark>`. Dojjo (`djo switch/list/merge`) becomes usable once the repo is jj.

## Gotchas

- Never run `jj git init` with `-R` against an uninitialized repo — it errors. `cd` into the target.
- Conversion makes no commits and no file changes; no branch/PR needed for the conversion itself.
- The user's pre-existing uncommitted work lands in `@` with no description — leave it; the user describes/squashes when ready.
- Feature branches pushed earlier stay as remote-tracking bookmarks even after their PRs merged — harmless; `jj bookmark delete` local copies + `jj git push --delete` to clean up, or just leave them.
