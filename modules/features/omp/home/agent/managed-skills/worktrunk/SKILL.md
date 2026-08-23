---
name: worktrunk
description: Reference for working with git worktrees via the Worktrunk (wt) CLI in agent workflows.
---

# Worktrunk quick reference

Worktrunk is a CLI that makes git worktrees as easy as branches. Use it to isolate each feature or agent task in its own worktree.

## Core commands

- `wt switch <branch>` — Switch to an existing worktree, or create one if the branch exists without a worktree.
- `wt switch --create <branch>` — Create a new branch and worktree from the default branch.
- `wt switch --create <branch> --base <base>` — Create from a specific base.
- `wt list` — Show all worktrees, status, divergence, and CI/PR info.
- `wt merge [<target>]` — Commit/squash, rebase onto target, fast-forward merge, and remove the worktree. Defaults to the default branch.
- `wt remove [<branch>]` — Remove the worktree and delete the branch if it is merged/empty.

## Shortcuts

- `^` — default branch (main/master)
- `@` — current branch/worktree
- `-` — previous worktree
- `pr:123` — GitHub PR #123 branch
- `mr:123` — GitLab MR !123 branch

Examples:

```bash
wt switch ^                    # back to main worktree
wt switch -                    # previous worktree
wt switch --create feat-auth   # new branch + worktree
wt switch pr:123               # checkout a PR branch
wt merge ^                     # merge current branch into main
```

## Agent workflow

When asked to implement a feature or fix, prefer an isolated worktree:

```bash
# Start work on a new branch
wt switch --create <branch>

# Do the work, then inspect
wt list
wt step diff                 # all changes since branching

# Finish — this commits, squashes, rebases, merges to main, and cleans up
wt merge
```

For parallel agents, launch each in its own worktree from the shell:

```bash
wt switch --create -x claude feat-a -- 'Implement feature A'
wt switch --create -x claude feat-b -- 'Fix bug B'
```

Inside an agent session, the current worktree is the working directory; do not `cd` out of it without a reason.

## Important flags

- `--no-hooks` — skip configured hooks.
- `--no-squash` — preserve individual commits when merging.
- `--no-remove` — keep worktree after `wt merge`.
- `--force` / `-f` — remove a dirty worktree.
- `--force-delete` / `-D` — delete an unmerged branch.
- `--reap` — kill processes running in the worktree before removal (Unix).

## Configuration

- User config: `~/.config/worktrunk/config.toml`
- Project config: `.config/wt.toml` (committed, shared)
- `wt config show` — show current config and file locations.
- `wt config create` — create a user config with examples.
- `wt config create --project` — create project config.

### Useful project config

```toml
[pre-start]
install = "npm ci"

[pre-merge]
test = "npm test"
lint = "npm run lint"

[post-start]
dev = "wt step tether -- npm run dev -- --port {{ branch | hash_port }}"

[list]
url = "http://localhost:{{ branch | hash_port }}"
```

## Common patterns

- `wt step commit` — stage and commit with LLM-generated message.
- `wt step diff` — show all changes since branching (committed, staged, unstaged, untracked).
- `wt step copy-ignored` — copy gitignored caches (e.g. `node_modules/`) between worktrees.
- `wt step prune` — remove worktrees and branches already merged into main.
- `wt hook <type>` — run hooks manually.

## Safety notes

- Never do long-running feature work directly on the default branch.
- Always create a worktree for each distinct task.
- Before running `wt merge`, ensure the default branch worktree is up to date if you need those changes.
- Use `wt list` frequently to see which worktrees are dirty, ahead, or safe to remove.
- If a worktree has conflicts after `wt merge`, resolve them in place and re-run `wt merge`.

## Docs

- https://worktrunk.dev/worktrunk/
