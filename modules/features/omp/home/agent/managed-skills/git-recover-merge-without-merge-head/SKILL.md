---
name: git-recover-merge-without-merge-head
description: "Finish an abandoned git merge when .git/MERGE_HEAD is gone (lost first-parent identity): recover the parent from ORIG_HEAD plus reflog, resolve remaining conflicts, then recreate the two-parent merge with git commit-tree + git update-ref so GitHub sees the PR as mergeable. Also covers content-proof diffing for already-merged squash branches and the Nix flake multi-attr package conflict resolution rule."
---

# Recovering an abandoned merge with no MERGE_HEAD

## Symptoms

- `git status --short` shows `UU <file>` (typically `flake.nix`) plus staged/unstaged merge changes.
- `git status` does **not** say "You have unmerged paths" and shows plain "Changes to be committed".
- `git commit --no-edit` fails with `Aborting commit due to empty commit message`.
- `git diff --name-only --diff-filter=U` reports 0 unmerged paths despite the markers being present in the file.
- `.git/MERGE_HEAD`, `.git/MERGE_MSG`, `.git/MERGE_MODE` are missing; `.git/ORIG_HEAD` and `.git/AUTO_MERGE` exist.

## Diagnosis

`git diff --diff-filter=U` reads the **index**. If a tool (or an aborted resolution attempt) reset the index, unmerged stages are collapsed to a single stage-0 entry, and `UU` in `git status --short --untracked-files=all` becomes stale/cosmetically wrong. Git then has no merge to continue, so `--no-edit` has no message.

Critical consequence: **the first parent is unrecoverable from files alone.** Do not assume `HEAD` is the merge target — the worktree may have been checked out to a different branch after the abandoned merge. Verify explicitly.

## Procedure

1. **Read the real state.**
   ```bash
   cd .git && for f in MERGE_HEAD MERGE_MSG MERGE_MODE AUTO_MERGE ORIG_HEAD; do
     if test -e $f; then echo "EXISTS $f: $(wc -c < $f) bytes"; else echo "MISSING $f"; fi
   done
   ```
   Also read `.git/MERGE_MSG` if present — it records the intended merge
   (`Merge remote-tracking branch 'origin/main' into <branch>`) and the conflicted files.

2. **Recover the missing first parent.**
   ```bash
   git reflog show HEAD --date=iso | head -20
   ```
   `ORIG_HEAD` is not the merge's first parent — it is the tip fetched/pulled
   *into*. For a `merge origin/main into feat/X` with sibling branches, the first
   parent is the branch tip that was checked out at the time (the reflog entry
   immediately before the fetch/merge). Cross-check with `git branch -vv`.
   Sanity check the recovered pair: `git merge-base <p1> <p2>` should equal the
   branch's old base (e.g. `9b4dd18`), and both must descend from it.

3. **Resolve conflicts with the conflict:// tooling** if markers are registered
   (`write({path: "conflict://<id>", content})`), else edit directly. Confirm the
   file is marker-free and semantically sound — `git grep -n -E '^(<<<<<<<|>>>>>>>)'`.

4. **Recreate the merge with plumbing** (there is no `MERGE_HEAD`, so
   `git commit` cannot produce a two-parent commit):
   ```bash
   git add -A
   tree=$(git write-tree)
   c=$(git commit-tree "$tree" -p <first-parent> -p <second-parent> -m "<merge message>")
   git update-ref HEAD "$c"
   ```
   `git update-ref HEAD` moves the *current branch* — verify `git branch --show-current` is the feature branch, not the default branch (repo rules forbid direct default-branch edits).

5. **Verify before pushing.**
   ```bash
   git log --oneline --graph -4          # expect the two-parent diamond
   git diff <other-parent-tip> HEAD -- <release-path>   # empty if main already had it
   ```
   Then push and check GitHub's mergeability:
   ```bash
   gh pr view <N> --json mergeable,mergeStateStatus   # CLEAN / MERGEABLE
   ```

6. **After a squash merge, prove tree equality.** GitHub's squash commit must
   match what you tested:
   ```bash
   git rev-parse origin/main^{tree}   # == the tested tree oid
   ```

## Don't merge branches whose content already landed

A squash-merged branch's tip is not an ancestor of main, so `git branch --merged` will not list it. Prove emptiness by **content diff**, not ancestry:

```bash
git diff --stat origin/main <branch-tip> | wc -l    # 0 → nothing to merge
```

The `feat/<N>` branch that produced squash commit `<sha>` is empty iff
`git diff <sha> <feat-tip>` is empty (the squash commit carries the same content).

## Nix flake multi-attr package conflicts

When both sides add/changed distinct attributes in `packages.<sys>`, and one
side **deletes a helper** (e.g. #58 removed `denoPkg` while retargeting
`default = playerPkg`), keep *ours* and append *theirs'* new attr:

```nix
stremio-accru         = playerPkg pkgs;      # ours: retargeted
stremio-accru-release = releasePkg pkgs;     # theirs: new attr from main
default               = playerPkg pkgs;      # ours
```

Taking *theirs* wholesale would leave a reference to the deleted helper and
break eval. Always **eval before committing**, since a dangling binding only
surfaces at eval time:

```bash
nix eval .#packages.x86_64-linux --apply builtins.attrNames
nix eval .#apps.x86_64-linux --apply builtins.attrNames
```

Post-merge, sweep the merged tree for the deleted symbol
(`git grep -n -E 'denoPkg|denoApp' main -- .`) — a surviving hit inside a
*comment* is harmless; a hit in code is a bug.

## Release-vs-dev artifact distinction worth checking

Nix-wrapped binaries carry a store interpreter + store rpath and run on NixOS
only; `deno compile` output keeps `/lib64/ld-linux-x86-64.so.2` and runs on
stock glibc. Verify before pointing a tag-release leg at a dev package:

```bash
patchelf --print-interpreter <inner-elf>   # store path → NixOS-only
file <binary>                              # /lib64/ld-linux-... → portable
```

Note: `nix build .#wrapper` yields a **bash wrapper**; the ELF is at the
`…-player-<ver>/bin/…` path referenced inside that wrapper.
