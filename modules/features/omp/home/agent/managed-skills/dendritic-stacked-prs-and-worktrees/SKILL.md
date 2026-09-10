---
name: dendritic-stacked-prs-and-worktrees
description: "Create stacked, issue-linked PRs in the dendritic flake (or any worktree-based repo): base-chain PRs, the three gh stack failure modes with worktrees, reverting a half-run gh stack init, rebasing a child branch after a parent update, attributing the pre-existing Nix CI pure-eval manpath failure, and STE-linting issue/PR prose. Use when opening a second stacked PR, when gh stack refuses to run, or when CI eval jobs are red."
---

# Stacked PRs in dendritic when worktrees hold the branches

Verified 2026-09-10 on `cernoh/dendritic` (jj-colocated git repo, `.worktrees/` convention). Complements the existing `dendritic-feature-change-verification` skill, which owns the eval gates.

## `gh stack` does not work in this repo (three failure modes)

- `gh stack init fix/147-a feat/146-b` → `✗ switching to branch feat/146-b: failed to run git: fatal: 'feat/146-b' is already used by worktree at …/.worktrees/computer-use`. The extension checks branches out, and the worktree workflow already owns them.
- `gh stack submit --auto` from the main checkout → `✗ branch "main" belongs to multiple stacks; checkout a non-trunk branch first`. Older stacks keep trunk `main` in `.git/gh-stack`.
- `gh stack submit --auto` from inside a worktree → `✗ current branch "feat/146-b" is not part of a stack`. The extension reads `.git/gh-stack` through the worktree's own gitdir, so it never sees the shared metadata.

A half-run `gh stack init` writes a stack entry into `.git/gh-stack` before failing on the checkout. Revert it by filtering `JSON.parse(file).stacks` for your branches and writing the JSON back. The file is plain JSON inside `.git/`, so nothing tracks the change.

## What works: base-chain PRs

1. Issue first (`gh issue create`), STE-linted.
2. Worktree per branch: `git worktree add .worktrees/<name> -b <type>/<N>-<topic>`.
3. Branch B off A: `git worktree add .worktrees/b -b feat/<N2>-<topic> fix/<N1>-<topic>`.
4. `gh pr create --base main` for A, `--base <branch-A>` for B. GitHub renders the chain, and review order is A then B.
5. Tag every title: `gh pr edit <n> --title "<title> (#<n>)"`.
6. Commits pushed to A after B exists: run `git rebase <branch-A>` inside B's worktree, then `git push --force-with-lease`.
7. Remove the worktrees once the work is pushed and mapped to PRs. Keep the branches until the PRs merge.

## CI attribution in this repo

- `Nix CI` fails on `main` since 2026-09-07. The eval jobs die on pure eval forcing `home-manager.users.<user>.home.file.".manpath"` → `error: in pure evaluation mode, 'fetchurl' requires a 'sha256' argument`. Root cause: the omp feature's impure `builtins.fetchurl` auto-update reaches MANPATH.
- Do not attribute that failure to your change. Reproduce with a plain pure eval (`nix eval --accept-flake-config --raw .#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath`) in a worktree based on main HEAD and in the untouched main checkout. Identical failures mean pre-existing.
- `Flake check`, `Format Nix (changed files)`, and `Lint prose` pass and are the signals to watch.

## STE prose gate

Feed the linter `title + "\n\n" + body` on stdin. Python 3 is not in PATH here.

```bash
printf '%s\n\n%s\n' "$TITLE" "$BODY" | nix shell nixpkgs#python3 --command python3 .github/scripts/ste-lint.py
```

- Sentences must stay at 20 words or fewer. The linter splits on dots, so a bullet that lists dotted paths or versions counts each fragment as a word (a six-package list with versions scored 23).
- Put long machine lists in a fenced code block. The linter excludes fenced code.
- `read`-tool output for the lint is JSON: check `total == 0` before creating or editing the issue or PR.
