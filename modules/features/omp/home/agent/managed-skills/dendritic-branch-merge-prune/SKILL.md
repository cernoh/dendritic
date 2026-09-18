---
name: dendritic-branch-merge-prune
description: "Merge every branch into main and prune in the cernoh/dendritic (jj-colocated) repo: the decisive tip==merged-PR-headRefOid containment test, rescuing staged-only work in a worktree before prune, gh pr merge --squash --delete-branch, and jj workspace forget plus dir removal. Use when asked to merge all branches to main, prune branches, or clean up worktrees in dendritic."
---

# Merge all branches into main, then prune (cernoh/dendritic)

Verified 2026-09-17 on dendritic `0d092b8` → `0cc5eab` (PRs #213, #215).

## Order of operations

1. `git fetch origin --prune`
2. Classify: `git branch -r --merged origin/main`, `--no-merged`, `git branch` (local).
3. **Prove containment before deleting** (next section).
4. Land any unmerged work as an issue-linked PR; merge it.
5. Remove worktrees, delete local + remote branches, forget jj bookmarks/workspaces, re-verify.

## The containment test that works

`tip == merged PR headRefOid` is the decisive proof. Loop:

```bash
for b in $(git for-each-ref --format='%(refname:strip=3)' refs/remotes/origin); do
  case "$b" in HEAD|main) continue;; esac
  tip=$(git rev-parse "origin/$b")
  hd=$(gh pr list --repo cernoh/dendritic --head "$b" --state merged --limit 1 --json headRefOid --jq '.[0].headRefOid')
  [ "$tip" = "$hd" ] && echo "OK $b" || echo "DIFF $b"
done
```

Two false-positive traps — do **not** trust either as "unmerged":

- `git diff --stat <mergeCommit> origin/<branch>`: non-empty whenever main gained unrelated content after that squash merge. Empty diff is proof of containment; non-empty proves nothing.
- Per-file blob containment against main: fails for files a later PR edited (README/AGENTS tables, `noctalia/default.nix`, `catppuccin/default.nix`, `omp/default.nix`), because GitHub's 3-way merge produced a blob the branch never had.

`git branch -r --merged` alone misses squash merges (tips stay outside ancestry). `%(refname:strip=3)` avoids the `origin/origin` bug when stripping `origin/` with sed.

## Rescue staged-only work first

A worktree can hold **staged-only** content that exists nowhere else: `git worktree remove` deletes it, and no ref/branch carries it. Check every worktree:

```bash
for w in .worktrees/*; do echo "== $w"; git -C "$w" status --short | head; done
```

If `git status --short` shows `A `/`M ` entries: `git add -A && git commit` in the worktree, then `git rebase origin/main`, then open the issue-linked PR. `git branch -a -vv` proving the branch tip is an ancestor of main says nothing about uncommitted files.

Also: an unpushed local commit can be superseded content. Prove it with the added-lines direction (`git diff origin/main <sha> -- <path>`) and compare with main's current values, not with the branch's base.

## Merge and prune

```bash
gh pr merge <n> --repo cernoh/dendritic --squash --delete-branch
git worktree remove .worktrees/<path>
git branch -D <merged-branches>          # -D, not -d: squash-merged tips are not ancestors
git push origin --delete <b1> <b2> ...   # one call for all remote branches
git fetch origin --prune
```

jj-colocated cleanup (needed: `git branch -D` does not clear jj workspaces):

```bash
jj bookmark list                 # deletions auto-import; only main should remain
jj workspace list
jj workspace forget <orphan-workspaces>
```

## jj workspace directory leftovers

`jj workspace forget` (or auto-abandon on import) leaves the directory on disk with a full checkout. Before `rm -rf`, diff each tree against main's tracked set:

```js
const tracked = new Set(sh("ls-files").split("\n"));
// walk dir, skip .jj/.git/.worktrees, report files whose relpath is not in `tracked`
```

Expect differences only for files main deleted since (e.g. `modules/features/catppuccin/default.nix`). Any other path = untracked leftover; stop and report.

`djo list` is the dojjo registry: forgotten workspaces drop off it, so no registry cleanup is needed.

## End-state checks

```bash
git branch            # main only
git worktree list     # main only
git ls-remote --heads origin | sed 's#.*refs/heads/#remote #'
jj bookmark list      # main only
jj workspace list     # default only
```

Then confirm the user's WIP survived the jj import/rebases: `git status --short` count and `git diff --stat`, plus the files you merged (`ls modules/features/<new>`).

## Side effects to report, not silently fix

Running `python3 .github/scripts/ste-lint.py` creates `.github/scripts/__pycache__/*.pyc`; `.gitignore` holds only `.planning/` and `/.worktrees/`, so jj snapshots that pyc into `@` and it shows as ` A`. Name it to the user (`__pycache__/` is a one-line ignore fix), do not delete their tree.
