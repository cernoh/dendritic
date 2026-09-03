---
name: omp-worktree
description: "Create isolated worktree under .worktrees/ inside the repo (gitignored) for new work — use git worktree (or djo/jj when suitable). Use when starting any new feature, fix, or parallel work."
---

# OMP Worktree — isolated work under .worktrees/

Always create an isolated worktree/workspace when starting something new.
Put it under `<repo>/.worktrees/<branch>` (same folder as the repo, never `~/.omp`, never sibling `../`).
Mark `.worktrees/` as gitignored so worktrees don't pollute `git status`.

## Detection

```bash
# jj available and repo is jj-backed?
jj root >/dev/null 2>&1 && echo "jj"
which djo >/dev/null 2>&1 && djo --help | head -1
git rev-parse --is-inside-work-tree 2>/dev/null && echo "git"
```

## Policy

- **Location:** `.worktrees/<branch>` inside the repo (`<repo>/.worktrees/<branch>`). Sanitize `/` → `-` for display, but keep branch name with slashes in git: `.worktrees/<branch>` where branch is e.g. `fix/nix-run-ui` → `.worktrees/fix-nix-run-ui` or `.worktrees/fix-nix-run-ui` (mkdir -p handles it). Prefer `feat/<name>` style.
- **Gitignore:** ensure `.worktrees/` is in `<repo>/.gitignore` (add `/.worktrees/` or `.worktrees/` if missing).
- **Naming:** derive from task/branch (e.g. `fix/nix-run-ui`, `feat/123-add-auth`). Never auto-generated random names.
- Never work on the default branch or directly in the main checkout for new work.

## Git repo (and jj colocated)

Preferred for this policy — works for plain git and for jj-colocated (underlying git is still there). `jj workspace add` forbids paths inside the repo, so `git worktree` is the correct tool when the workspace must live under `.worktrees/`:

```bash
# from repo root
mkdir -p .worktrees
grep -qxF '.worktrees/' .gitignore || echo '.worktrees/' >> .gitignore
# jj colocated? ensure git knows about main
git fetch origin 2>/dev/null || true
git worktree add .worktrees/<branch> -b <branch> origin/main  # or main
# verify
git worktree list
cd .worktrees/<branch>
# copy env/caches if needed (from repo root)
cp ../.env* . 2>/dev/null || true
```

If a worktrunk wrapper exists:
```bash
bash "${CLAUDE_SKILL_DIR:-.}/scripts/worktree-manager.sh" create <branch>
# If wrapper created elsewhere, move to .worktrees:
# git worktree move <old-path> .worktrees/<branch>
```

## JJ repo (when outside path is allowed)

If policy allowed outside paths, you'd use `djo`/`jj workspace`. But this repo requires `.worktrees/` inside, so **do not use `jj workspace add .worktrees/...`** — it will error `path inside repo`. Use `git worktree` as above even when `jj`/`djo` are available. `jj log` still shows the git branch as a bookmark.

If you truly need a jj workspace, create it outside and symlink into `.worktrees/`:
```bash
jj workspace add --revision main ../workspace-<name>
ln -s ../workspace-<name> .worktrees/<branch>
```

## After work

```bash
# from repo root or worktree
git worktree remove .worktrees/<branch>
git branch -d <branch>  # after merge
git worktree list
# jj colocated: prune if needed
jj workspace list  # if you used a jj workspace
djo prune 2>/dev/null || true
```

## Agent workflow

1. Detect `jj` vs `git` and `djo` availability.
2. Derive `<branch>` from task.
3. `mkdir -p .worktrees` and ensure `.worktrees/` in `.gitignore`.
4. `git worktree add .worktrees/<branch> -b <branch> <base>` (base = origin/main or main).
5. `cd .worktrees/<branch>` and do all edits/commits. Never edit in the original checkout.
6. On finish, `git worktree remove .worktrees/<branch>` after PR merge.

## Troubleshooting

- `jj workspace add: workspace path inside repo` → expected; use `git worktree` for `.worktrees/` policy.
- `fatal: .worktrees/<branch> already exists` → `git worktree remove .worktrees/<branch>` or pick new name.
- `branch already exists` → `git branch -D <branch>` or reuse with `git worktree add --force`.
- `.worktrees` not ignored → `echo '.worktrees/' >> .gitignore` from repo root.
