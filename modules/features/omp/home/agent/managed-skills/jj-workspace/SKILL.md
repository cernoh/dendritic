---
name: jj-workspace
description: "Create an isolated jj workspace for parallel feature work. Use when the current directory is a Jujutsu (jj) repo and you need isolated work that should not disturb the current checkout, or when ce-work or ce-code-review offers a worktree option in a jj-backed repo."
---

# Jujutsu Workspace Creation

Create an isolated jj workspace for parallel feature work. Analogous to `git worktree` but uses jj's native workspace system.

**Key constraint:** jj workspaces MUST be outside the repo directory. Use sibling directories (e.g., `../workspace-<name>`), not nested paths like `.workspaces/`.

## When to use

- Starting work that should not disturb the current checkout
- Reviewing a PR while keeping the main workspace free
- Running multiple features in parallel
- When `ce-work` or `ce-code-review` offers a worktree option AND the repo is jj-backed

## Detection

Before using this skill, verify the directory is jj-backed:
```bash
jj st 2>/dev/null || echo "Not a jj repo"
```

If it's a git repo instead, use `ce-worktree` skill.

## Creating a workspace

```bash
jj workspace create ../workspace-<name> -r <rev>
```

Where:
- `<name>` is derived from the task (e.g., `feat-auth`, `fix-validation`)
- `<rev>` is the revision/bookmark to base it on (defaults to `@` if omitted)

Examples:
```bash
# Create workspace at current working copy
jj workspace create ../workspace-feat-auth

# Create workspace based on main bookmark
jj workspace create ../workspace-fix-validation -r main

# Create workspace from a specific change
jj workspace create ../workspace-review-pr -r xyz123
```

After creation, switch to the workspace:
```bash
cd ../workspace-<name>
```

## Workspace operations

```bash
jj workspace list                          # list all workspaces
jj workspace remove ../workspace-<name>    # remove a workspace
cd ../workspace-<name>                     # switch to a workspace
cd ..                                      # return to parent directory
```

## Env file handling

Workspaces don't automatically inherit `.env` files. Copy them manually:
```bash
# From the main repo (not from inside the workspace)
cp .env .env.local .env.test ../workspace-<name>/ 2>/dev/null || true
```

## Gitignore setup

Add workspace directories to `.gitignore` if not already present:
```bash
echo 'workspace-*' >> .gitignore 2>/dev/null || true
```

## Key differences from git worktree

- **No fetch required**: jj doesn't need `jj fetch` before creating a workspace
- **Revision-based**: Workspaces can be created at any revision, not just bookmarks
- **Independent working copies**: Each workspace has its own `@` commit
- **Native to jj**: No separate command; workspaces are first-class jj concepts
- **Sibling directories**: Workspaces must live outside the repo, unlike git worktrees which can nest

## Integration

When `ce-work` or `ce-code-review` offers a worktree option:
1. Detect if jj or git repo: `jj st 2>/dev/null && echo "jj" || echo "git"`
2. If jj: use `jj workspace create ../workspace-<name> -r <base>`
3. If git: use `ce-worktree` skill

Derive workspace name from the task description (e.g., `feat-auth`, `fix-validation`), not auto-generated names.

## Troubleshooting

**"Workspace already exists"**: the path is already in use. Either switch to it (`cd ../workspace-<name>`) or remove it (`jj workspace remove ../workspace-<name>`) before recreating.

**"Cannot remove workspace"**: ensure you're not inside the workspace when removing it. `cd` out first.

**Env files not working**: copy them manually from the main repo root, not from inside the workspace.

**"Failed to create workspace"**: verify the target path is outside the repo. jj workspaces cannot be nested inside the parent workspace directory.
