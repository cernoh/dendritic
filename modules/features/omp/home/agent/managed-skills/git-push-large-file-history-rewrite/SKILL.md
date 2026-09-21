---
name: git-push-large-file-history-rewrite
description: "Fix \"remote rejected ... exceeds GitHub's file size limit / GH001\" when a large blob (core dump, profile dir) is already committed in unpushed commits: locate the introducing commit, rewrite with filter-branch index-filter over the unpushed range so merge commits are rebuilt with their resolved trees, ignore the pattern, push, and verify honestly (jj-keep refs make git log --all lie)."
---

# Fix a GitHub push rejected by a committed large blob

Symptom:

```
remote: error: File <name> is 584.61 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: GH001: Large files detected.
 ! [remote rejected] main -> main (pre-receive hook declined)
```

A trailing `git rm --cached <file>` plus a new commit does NOT fix this. The blob is inside an
existing commit, so it still ships in the pack. The introducing commit MUST be rewritten.

## 1. Reproduce and locate

```bash
git push 2>&1 | tail -5                 # confirm the hook, not auth
git log --oneline origin/main..main     # the range that will ship
git log --oneline --all --name-status --diff-filter=A -- '*.core'   # introducing commit
git show --stat --format='%H %s' <sha>
```

Then find every oversized object that will ship (not just the one named in the error):

```bash
git rev-list --objects origin/main..main \
  | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' \
  | sort -k2 -n -r | sed -n '1,12p'
```

Objects between `origin/main` and the version you push are fine under 100 MB; only the
>100 MB rows matter. In the dendritic repo a single `.core` dominated (browser-profile blobs
sat at 17 MB, harmless).

## 2. Recognise the merge shape before rewriting

```bash
git log --format='%h %p %ci %s' origin/main..main
git log --graph --oneline -8 main
```

Typical accidental shape (a `git pull` merge on top of a side chain):

```
* 4b936b3 Merge branch 'main' of github.com:<owner>/<repo>   # parents: b76da58, 2cf695f
|\
| * 2cf695f  <- origin/main
* | b76da58  <- "nixd", added the 584 MB core
* | 70987e8
* | 831b239
|/
* dcae9f4
```

Rewriting `b76da58` forces recreating the merge too, or the old commit stays reachable from
`main`. Do NOT re-run `git merge` (that can conflict or drop an already-resolved tree).

## 3. Rewrite in place

`filter-branch` over the unpushed range rewrites exactly those commits, reparents the merge
onto the rewritten first parent automatically, and reuses each commit's existing tree — so the
merge keeps its resolution instead of being re-derived:

```bash
cd <repo>
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --force \
  --index-filter 'git rm --cached --ignore-unmatch "<exact-relative-path>"' \
  -- origin/main..main
```

Range, not `--all`: ancestors outside the range (including `origin/main`, the merge's second
parent) keep their original ids. Do not pass `--prune-empty` when the offending commit carries
real work (`nixd` also touched nvf/omp modules); it would be fine only for a commit that adds
nothing else. `filter-branch` writes a backup ref `refs/original/refs/heads/main`.

## 4. Prove the rewrite is content-preserving

```bash
git log --oneline origin/main..main
git diff --name-status refs/original/refs/heads/main main
```

The diff MUST be exactly the deleted blobs:

```
D	qemu_nixd-attrset-eval_20260920-214447_97996.core
```

Any other line means the rewrite changed real content — stop and recover.

## 5. Stop it recurring, then push

Add the pattern to `.gitignore` and commit it:

```
*.core
```

This also stops `jj` refusing to snapshot the working copy
(`Refused to snapshot … the maximum size allowed is 5.0MiB`), which is the same junk file
surfacing in the jj layer.

```bash
git add .gitignore && git commit -m "chore: ignore qemu core dumps"
git push 2>&1 | tail -5          # expect: 2cf695f..<new> main -> main
git ls-remote origin refs/heads/main
git update-ref -d refs/original/refs/heads/main    # drop filter-branch's backup ref
```

## 6. Verify honestly — `--all` lies in a jj-colocated repo

```bash
git log --all --oneline -- '*.core'                    # may STILL print the old commit
git rev-list --objects origin/main..main | grep -ci core   # -> 0
git rev-list --objects refs/heads/main | grep -ci core     # -> 0  (what actually ships)
git cat-file --batch-check --batch-all-objects --unordered \
  | awk '$1=="blob" && $2>50000000 {print $2, $3}'         # -> empty
```

`jj` keeps old commits alive through `refs/jj/keep/*`, so `git log --all` and
`refs/original` can still show the pre-rewrite commit. That is not a failure. The only proofs
that count: the range/reachable-object counts are zero and the push was accepted.

After rewriting a jj-colocated repo, let jj re-import once and read the result:

```bash
jj status   # expect: "Reset the working copy parent to the new Git HEAD", "no changes"
```

jj rebases the working-copy commit onto the rewritten head by itself; do not hand-fix it.

## Pitfalls

- Fixing with `git rm --cached` + commit: blob still in the old commit, push still rejected.
- `git log --all` showing the old commit after a correct rewrite: jj-keep refs, not a bug.
- Re-running `git merge origin/main` to rebuild the merge: risks conflicts and losing the
  resolved tree; filter-branch reparents instead.
- Leaving the core dumps on disk is fine once `*.core` is ignored; deleting a user's crash
  dump is a destructive act — report the path and size, do not remove it unasked.
