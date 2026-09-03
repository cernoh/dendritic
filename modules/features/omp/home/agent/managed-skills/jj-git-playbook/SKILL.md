---
name: jj-git-playbook
description: "Colocated jj+git workflow — command translation table (git vs jj) for init, clone, fetch, push, status, diff, log, bookmarks, etc."
---

# jj + Git Playbook — Colocated Workflow

Use when the repo is `jj+git` colocated (`jj git init` with Git backing, `jj` working copy on top of `git` HEAD). The underlying Git repo remains the source of truth for remotes/CI; `jj` is the working-copy/commit layer. Keep both in sync.

## When to use this skill

- `jj status` shows dirty / `git status` diverges — need equivalent commands.
- Creating, cloning, fetching, pushing, or moving bookmarks between Git and jj.
- Translating a `git` habit to the `jj` idiom (or vice-versa) inside this checkout (`/home/davr/active` pattern — `jj` on top of `git` with `.jj/` + `.git/`).

## Colocated invariants

- **Never mix push paths without syncing:** after `jj` operations that create bookmarks/commits, `jj git push` (or `git push` after `jj` export) is required to update `origin`. After `git commit` directly, `jj` will import (`Done importing changes from the underlying Git repo`).
- **Bookmark tracking:** `jj` bookmarks that track a remote need `jj bookmark track <name>@origin` after the remote appears (`Warning: Non-tracking remote bookmark` hint).
- **`git remote -v` empty** → no GitHub remote yet; check `gh auth status` then `jj git remote add` / `git remote add` or `gh repo create`.
- **Ignored blobs:** `sources/`, `*.img`, `*.tar.gz`, `*.zip`, `result*` remain gitignored — never `git add` them even if `jj` shows them as untracked.

## Command translation table

| Use case | Git command | Jujutsu command | Notes |
|---|---|---|---|
| Create a new repo | `git init` | `jj git init [--no-colocate]` | Colocated is default for interop; `--no-colocate` for pure jj. |
| Clone an existing repo | `git clone <source> <destination> [--origin <remote name>]` | `jj git clone <source> <destination> [--remote <remote name>]` | There is no support for cloning non-Git repos yet. |
| Update the local repo with all bookmarks/branches from a remote | `git fetch [<remote>]` | `jj git fetch [--remote <remote>]` | There is no support for fetching into non-Git repos yet. |
| Update a remote repo with all bookmarks/branches from the local repo | `git push --all [<remote>]` | `jj git push --all [--remote <remote>]` | There is no support for pushing from non-Git repos yet. |
| Update a remote repo with a single bookmark from the local repo | `git push <remote> <bookmark name>` | `jj git push --bookmark <bookmark name> [--remote <remote>]` | There is no support for pushing from non-Git repos yet. |
| Add a remote target to the repo | `git remote add <remote> <url>` | `jj git remote add <remote> <url>` | Either works; `jj` wraps git remote. |
| Show summary of current work and repo status | `git status` | `jj st` | `jj st` shows working-copy changes + parent. |
| Show diff of the current change | `git diff HEAD` | `jj diff` | `jj diff` is working-copy vs parent. |
| Show diff of another change | `git diff <revision>^ <revision>` | `jj diff -r <revision>` |  |
| Show diff from another change to the current change | `git diff <revision>` | `jj diff --from <revision>` |  |
| Show diff from change A to change B | `git diff A B` | `jj diff --from A --to B` |  |
| Show all the changes in A..B | `git diff A...B` | `jj diff -r A..B` |  |
| Show description and diff of a change | `git show <revision>` | `jj show <revision>` |  |
| Add a file to the current change | `touch filename; git add filename` | `touch filename` | jj tracks automatically; no `add` needed. |
| Remove a file from the current change | `git rm filename` | `rm filename` |  |
| Remove a previously tracked file from the current change, but keep it in the working copy | `git rm --cached filename` | `jj file untrack filename` | File name must match an ignore pattern to remain untracked. See docs for working copies. |
| Modify a file in the current change | `echo stuff >> filename` | `echo stuff >> filename` |  |
| Finish work on the current change and start a new change | `git commit -a` | `jj commit` | `jj commit` closes current change, opens new empty one. |
| See compact log graph of ancestors of the current commit | `git log --oneline --graph` | `jj log -r ::@` |  |
| See compact log graph of all reachable commits | `git log --oneline --graph --all` | `jj log -r 'all()' or jj log -r ::` | In a Git-backed jj repo `git log --all` also shows hidden jj commits. Exclude with `--exclude refs/jj/* --all`. |
| Show compact log graph of commits not on the main branch | `git log --oneline --graph --branches --not upstream/main` | `jj log` | Default `jj log` shows not-on-main. |
| Show log of commits that have the string "stuff" in changed lines (pickaxe) | `git log -G stuff` | `jj log -r 'diff_lines(regex:stuff)'` |  |
| List versioned files in the working copy | `git ls-files --cached` | `jj file list` |  |
| Search among files versioned in the repository | `git grep foo` | `jj file search --pattern=foo or rg --no-require-git foo` |  |
| Abandon the current change and start a new change | `git reset --hard` (cannot be undone) | `jj abandon` |  |
| Make the current change empty | `git reset --hard` (same as abandoning) | `jj restore` |  |
| Abandon the parent of the working copy, but keep its diff in the working copy | `git reset --soft HEAD~` | `jj squash --from @-` |  |
| Discard working copy changes in some files | `git restore <paths>...` or `git checkout HEAD -- <paths>...` | `jj restore <paths>...` |  |
| Edit description (commit message) of the current change | Not supported | `jj describe` |  |
| Edit description (commit message) of the previous change | `git commit --amend --only` | `jj describe @-` |  |
| Edit description (commit message) of any change | `git commit --fixup=reword:X; git rebase --autosquash X^` | `jj describe X` |  |
| Temporarily put away the current change | `git stash` | `jj new @-` | Old working-copy commit remains as sibling; restore with `jj edit X`. |
| Start working on a new change based on the bookmark/branch | `git switch -c topic main` or `git checkout -b topic main` (may need stash/commit first) | `jj new main` |  |
| Merge branch A into the current change | `git merge A` | `jj new @ A` |  |
| Check out a named revision (or branch) to examine source | `git checkout v1.0.1` | `jj new v1.0.1` | Creates new empty change on top (see jj new main). |
| Move bookmark/branch A onto bookmark/branch B | `git rebase B A` (may need separate rebases) | `jj rebase -b A -o B` |  |
| Move change A and its descendants onto change B | `git rebase --onto B A^ <some descendant bookmark>` | `jj rebase -s A -o B` |  |
| Reorder changes from A-B-C-D to A-C-B-D | `git rebase -i A` | `jj rebase -r C --before B` |  |
| Reorder multiple commits at once | `git rebase -i` | `jj arrange` |  |
| Move the diff in the current change into the parent change | `git commit --amend -a` | `jj squash` |  |
| Interactively move part of the diff in the current change into the parent change | `git add -p; git commit --amend` | `jj squash -i` |  |
| Move the diff in the working copy into an ancestor | `git commit --fixup=X; git rebase --autosquash X^` | `jj squash --into X` |  |
| Interactively move part of the diff in an arbitrary change to another arbitrary change | Not supported | `jj squash -i --from X --into Y` |  |
| Interactively split the changes in the working copy in two | `git commit -p` | `jj split` |  |
| Interactively split an arbitrary change in two | Not supported (emulated with "edit" in rebase -i) | `jj split -r <revision>` |  |
| Interactively edit the diff in a given change | Not supported (emulated with "edit" in rebase -i) | `jj diffedit -r <revision>` |  |
| Resolve conflicts and continue interrupted operation | `echo resolved > filename; git add filename; git rebase/merge/cherry-pick --continue` | `echo resolved > filename; jj squash` | Operations don't get interrupted, so no need to continue. |
| Create a copy of a commit on top of another commit | `git co <destination>; git cherry-pick <source>` | `jj duplicate <source> -o <destination>` |  |
| Find the root of the working copy (or check if in a repo) | `git rev-parse --show-toplevel` | `jj workspace root` |  |
| List bookmarks/branches | `git branch` | `jj bookmark list` or `jj b l` for short |  |
| Create a bookmark/branch | `git branch <name> <revision>` | `jj bookmark create <name> -r <revision>` |  |
| Move a bookmark/branch forward | `git branch -f <name> <revision>` | `jj bookmark move <name> --to <revision>` or `jj b m <name> -t <revision>` |  |
| Move a bookmark/branch backward or sideways | `git branch -f <name> <revision>` | `jj bookmark move <name> --to <revision> --allow-backwards` |  |
| Delete a bookmark/branch | `git branch --delete <name>` | `jj bookmark delete <name>` |  |
| List tags | `git tag -l` | `jj tag list` |  |
| Create a tag | `git tag <name> <revision>` | `jj tag set <name> -r <revision>` |  |
| Delete a tag | `git tag -d <name>` | `jj tag delete <name>` |  |
| List tags that contain a revision | `git tag --contains <revision>` | `jj tag list -r '<revision>::'` | Uses jj's revset; `::` postfix = descendants. |
| List tags merged into a revision | `git tag --merged <revision>` | `jj tag list -r '::<revision>'` | `::` prefix = ancestors. |
| See log of operations performed on the repo | Not supported | `jj op log` |  |
| Undo the last operation | Not supported | `jj undo` | Also `jj redo` to redo. |
| Revert an earlier operation | Not supported | `jj op revert` |  |
| Create a commit that cancels out a previous commit | `git revert <revision>` | `jj revert -r <revision> -B @` |  |
| Show what revision and author last modified each line of a file | `git blame <file>` | `jj file annotate <path>` |  |

## Quick recipes for this repo

**Check state:** `jj st` / `git status --short` / `jj log -n 3` / `git log --oneline -3`
**Before editing on default branch:** `jj new main` (or `git switch -c feat/... main`)
**After `jj commit`:** `jj git push --bookmark main` or `jj git push --all`
**After `git commit` on colocated:** `jj` auto-imports on next `jj st`/`jj log`
**New GitHub remote:** `gh auth status` → `jj git remote add origin <url>` → `jj git push --all`
