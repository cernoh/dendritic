---
name: jj-verify-prune-merged-branches
description: Verify every branch is part of main (including squash-merged PRs whose tips are not ancestors) and prune all local+remote bookmarks/branches in a colocated jj repo
---

# Verify branches are in main, then prune (jj colocated)

Use after a repo conversion to jj (`jj git init --colocate`) or as routine cleanup: user says "ensure all branches are part of main and prune all bookmarks".

## Critical gotcha

`git branch -r --merged origin/main` (ancestor check) is NOT sufficient. GitHub squash-merges leave branch tips OUTSIDE main's ancestry — ancestor checks false-flag them as unmerged. Validate content, not topology.

## 1. Enumerate and classify (one fast pass)

```bash
git fetch origin --prune        # ground truth; note upstream-deleted branches
git ls-remote --heads origin    # actual remote branches
git branch -r --merged origin/main      # -> merged (ancestors): safe
git branch -r --no-merged origin/main    # -> must verify via PR merge commits
git branch | grep -v '^main'            # local-only branches (upstream deleted post-merge)
```

Never loop per-branch `git merge-base --is-ancestor` in a bash while-read — pathologically slow. Use the `--merged`/`--no-merged` classification (single fast call).

## 2. Verify non-ancestor branches via PR merge commits

```bash
gh auth status                  # confirm authenticated first
gh pr list --repo OWNER/REPO --state all --json number,state,headRefName --template '{{range .}}{{printf "%s\t%s\t%d\n" .headRefName .state .number}}{{end}}'
gh pr view <n> --repo OWNER/REPO --json headRefName,mergeCommit --jq '.headRefName + " " + .mergeCommit.oid'
git diff --stat <mergeCommit-oid> origin/<branch>   # EMPTY output == branch content landed in main
```

Empty diff vs the PR's merge commit is the proof. Local-only branches (upstream already deleted): `git rev-list --count main..<branch>` == 0 means merged.

## 3. No-PR branches (bot/copilot leftovers)

No PR in `gh pr list` ≠ safe. Check:
- Copilot/draft branch whose feature exists in main: diff the branch's file blobs against the commit that introduced the feature to main (`git log --diff-filter=A origin/main -- <path>`), or `git diff-tree` the path — identical blob == merged.
- `automation/update-flake-lock` style: compare input revs/dates vs main's current lock; a stale lock bump is superseded content (workflow regenerates the branch). Same nixpkgs `lastModified` in both = contained.

## 4. Prune

```bash
jj bookmark delete <b1> <b2> ...            # colocated export removes git branches too
git push origin --delete <b1> <b2> ...      # batch ALL remote branches in one call
git fetch origin --prune
```

jj auto-imports deletions and auto-abandons now-unreachable commits ("Abandoned N commits") — objects stay in `.git` until GC, so it is recoverable. Never delete a branch before the empty-diff/ancestor proof in step 2-3.

## 5. Verify

```bash
git ls-remote --heads origin | wc -l   # 1 (main only)
git branch                            # main only
jj bookmark list                      # main only
jj st                                 # working-copy @ intact, user edits untouched
```

Do NOT commit/squash the working copy unless asked — it holds the user's in-progress edits on top of main.

## Colocated init companion steps

`jj git init --colocate` runs in the repo dir (never with `-R` — that needs an existing jj repo). It prints a hint listing remote bookmarks not associated with local ones; run the suggested `jj bookmark track <b>@origin ...` so `jj git fetch`/`jj git push -b main` stay in sync. Local branches import as bookmarks; dirty trees import into `@` untouched.
