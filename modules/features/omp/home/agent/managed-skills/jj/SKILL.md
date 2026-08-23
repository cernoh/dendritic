---
name: jj
description: "Use when working with Jujutsu (jj), the Git alternative. Covers init, changes, bookmarks, revsets, rebasing, conflict resolution, git interop, and the operation log. Pull this skill before any jj invocation you're not 100% sure of."
---

# Jujutsu (jj) Reference

`jj` is a version control system that models history as a DAG of **changes** (not commits). Changes have stable IDs even as their content evolves. The working copy is always a commit. No staging area.

**Version installed:** 0.43.0

## Core Mental Model

| Git concept | jj equivalent |
|---|---|
| Commit | **Change** (has stable change ID + mutable commit ID) |
| Branch | **Bookmark** (named pointer, no "current" concept) |
| `git checkout` | `jj edit <change>` or `jj new` |
| `git add` | Automatic (working copy snapshots on every command) |
| `git commit --amend` | Edit files, then `jj describe` or next `jj` command |
| `git rebase -i` | `jj rebase`, `jj squash`, `jj split`, `jj diffedit` |
| Staging area | Doesn't exist; working copy is live |
| `.git/` | `.jj/` (plus backing Git repo in colocated mode) |

**Key difference:** In Git, the working copy is separate from commits. In jj, the working copy IS a commit (`@`). Edits auto-amend it until you `jj new` to start a fresh change.

## I want to… (task → command)

| I want to… | Do this |
|---|---|
| Start a new jj repo (Git backend) | `jj git init --colocate` (colocated with Git) |
| Clone a Git repo | `jj git clone <url>` |
| See current status | `jj st` or `jj status` |
| View history as a DAG | `jj log` |
| Set commit message | `jj desc` or `jj describe` |
| Start a new change on top of current | `jj new` |
| Start a new change on a specific parent | `jj new <revset>` |
| Edit an existing change | `jj edit <change-id>` |
| Amend current change with files | Just edit files; next `jj` command snapshots |
| Combine current change into parent | `jj squash` |
| Split a change into two | `jj split` |
| Interactively pick hunks to squash | `jj squash -i` |
| Edit a change's diff without checking out | `jj diffedit -r <rev>` |
| Discard working copy changes | `jj restore` |
| Discard changes in a specific file | `jj restore <path>` |
| Delete a change | `jj abandon <change-id>` |
| Move a change to a different parent | `jj rebase -s <src> -o <dst>` |
| Create a bookmark | `jj bookmark create <name>` |
| Move a bookmark to current change | `jj bookmark set <name>` |
| List bookmarks | `jj bookmark list` |
| Push a bookmark to Git remote | `jj git push -b <name>` |
| Push a single change without a bookmark | `jj git push --change <change-id>` |
| Fetch from Git remote | `jj git fetch` |
| Undo last operation | `jj undo` |
| View operation history | `jj op log` |
| Resolve conflicts | `jj resolve` or edit conflict markers directly |
| See how a change evolved | `jj evolog` |

## Essential Commands

### Working with Changes

```bash
jj st                                    # status: working copy + parent
jj log                                   # DAG of recent changes
jj log -r ::                             # ALL changes in repo
jj desc                                  # edit working copy's description
jj desc -m "Fix bug"                     # set description inline
jj new                                   # new empty change on top of @
jj new main                              # new change on top of main bookmark
jj edit xyz123                           # check out existing change for editing
jj squash                                # merge @ into parent (like git commit --amend)
jj squash -i                             # interactive: pick hunks to squash
jj split                                 # split @ into two changes
jj diffedit -r @-                        # edit parent's diff without checking it out
jj restore                               # discard all working copy changes
jj restore file.txt                      # discard changes to one file
jj abandon xyz123                        # delete a change (descendants rebase to its parent)
```

### Bookmarks (Git Branches)

```bash
jj bookmark list                         # local bookmarks
jj bookmark list --all                   # include remote-tracking
jj bookmark create feature-x             # create at current change
jj bookmark set feature-x                # move to current change
jj bookmark delete feature-x             # delete local bookmark
jj bookmark track feature-x --remote origin  # track remote bookmark
jj bookmark untrack feature-x --remote origin

# Push/pull (Git interop)
jj git fetch                             # fetch all remotes
jj git fetch --remote origin             # fetch specific remote
jj git push                              # push current bookmark if tracked
jj git push -b feature-x                 # push specific bookmark
jj git push --tracked                    # push all tracked bookmarks
```

### Rebasing and History Editing

```bash
# Rebase modes
jj rebase -s <src> -o <dst>              # move <src> + descendants onto <dst>
jj rebase -b <rev> -o <dst>              # rebase whole branch relative to <dst>
jj rebase -r <rev> -o <dst>              # rebase only <rev>, no descendants

# Examples
jj rebase -s @- -o main                  # move parent onto main
jj rebase -b feature -o main             # rebase feature branch onto main
jj rebase -r xyz123 -o abc456            # move one change, leave descendants behind
```

### Conflict Resolution

Conflicts in jj are first-class. They don't block rebases; they're stored in the commit.

```bash
jj st                                    # shows conflicted files
jj resolve                               # interactive resolver
jj resolve --tool meld                   # use specific merge tool
# OR: edit conflict markers directly in the file, then:
jj squash                                # merge resolution into conflicted parent
```

Conflict markers look like:
```
<<<<<<< conflict 1 of 1
%%%%%%% diff from: <base-rev>
\\\\\\\        to: <target-rev>
-base content
+target content
+++++++ <source-rev>
source content
>>>>>>> conflict 1 of 1 ends
```

### Operation Log (Undo/Time Travel)

Every `jj` command is recorded. You can undo anything or view repo state at any past operation.

```bash
jj op log                                # list operations
jj undo                                  # undo last operation
jj undo <operation-id>                   # undo specific operation
jj log --at-op=<operation-id>            # view repo at past operation
jj op restore <operation-id>             # restore repo to past state
```

## Revsets (Query Language)

Revsets select revisions. Used in `-r`, `jj log -r`, `jj edit`, etc.

### Symbols

| Symbol | Meaning |
|---|---|
| `@` | Working copy commit |
| `main` | Bookmark named "main" |
| `main@origin` | Remote-tracking bookmark |
| `<change-id>` | Change with that ID (e.g. `xyz123`) |
| `<commit-id>` | Commit with that hash (e.g. `abc123def456`) |
| `"literal"` | Literal string (prevents interpretation) |

### Operators

| Operator | Meaning | Example |
|---|---|---|
| `x-` | Parents of x | `@-` (parent of working copy) |
| `x+` | Children of x | `main+` (children of main) |
| `::x` | Ancestors of x (inclusive) | `::@` (all ancestors of working copy) |
| `x::` | Descendants of x (inclusive) | `@::` (all descendants of working copy) |
| `x::y` | Ancestry path from x to y | `main::feature` |
| `x..y` | Reachable from y but not x | `main..feature` (like Git's `main..feature`) |
| `::` | All visible commits | `jj log -r ::` |
| `~x` | NOT x | `~main` (everything except main) |
| `x & y` | Intersection | `@ & feature::` |
| `x \| y` | Union | `main \| feature` |
| `x ~ y` | Difference (x minus y) | `::feature ~ ::main` |

### Functions

| Function | Meaning |
|---|---|
| `roots(x)` | Revisions in x with no parents in x |
| `heads(x)` | Revisions in x with no children in x |
| `latest(x, n)` | N most recent revisions in x |
| `trunk()` | Mainline branch (configured, often `main@origin`) |
| `bookmarks()` | All bookmark targets |
| `tags()` | All tag targets |
| `git_head()` | Git HEAD equivalent |
| `working_copy()` | Same as `@` |
| `visible_heads()` | All visible head commits |
| `all()` | All visible commits |
| `none()` | Empty set |
| `ancestors(x)` | Same as `::x` |
| `descendants(x)` | Same as `x::` |
| `parents(x)` | Same as `x-` |
| `children(x)` | Same as `x+` |

### Examples

```bash
jj log -r '@ | main | feature'           # working copy + two bookmarks
jj log -r 'main::@'                      # ancestry path from main to working copy
jj log -r 'main..@'                      # changes on working copy not on main
jj log -r '::feature ~ ::main'           # changes unique to feature branch
jj log -r '@-'                           # parent of working copy
jj log -r 'heads(::main)'                # tip of main branch
jj log -r 'roots(main..feature)'         # first commit unique to feature
```

## Git Interop (Colocated Mode)

In colocated mode, jj and Git share the same `.git/` directory. You can use both tools interchangeably.

```bash
# Setup
jj git init --colocate                   # init jj in existing Git repo
# OR
jj git clone <url>                       # clone creates colocated repo

# Daily workflow
jj git fetch                             # pull from remote
jj log                                   # see what changed
jj new main                              # start work on main
# ... edit files ...
jj desc -m "Fix bug"                     # describe the change
jj git push -b main                      # push to remote

# Interop
git status                               # works (shows jj working copy)
git log                                  # works (shows jj commits)
jj git import                            # manually sync from Git (auto in colocated)
jj git export                            # manually sync to Git (auto in colocated)
```

**Colocated benefits:** Other tools (IDEs, CI scripts) see a normal Git repo. You get jj's ergonomics without breaking Git-based workflows.

## Common Workflows

### Stack of Changes (like git rebase -i)

```bash
# Create a stack
jj new main -m "First change"
# ... edit files ...
jj new -m "Second change"
# ... edit files ...
jj new -m "Third change"

# View the stack
jj log -r 'main::@'

# Edit a change in the middle
jj edit <change-id-of-second>
# ... make edits ...
jj new                                   # create new working copy on top

# Reorder: move third change before first
jj rebase -r <third-change-id> -o main

# Squash all into one
jj squash -r <third> -i                  # pick hunks
jj squash -r <second>
jj squash -r <first>
```

### Fixup / Amend Earlier Change

```bash
# You're at @, realize parent needs a fix
jj new @- -m "fixup! parent change"
# ... edit files ...
jj squash -r @ -i                        # interactively pick hunks to squash into parent
# OR: use jj absorb (experimental)
jj absorb                                # auto-move changes to ancestor that touched same lines
```

### Resolve Conflicts After Rebase

```bash
jj rebase -s feature -o main
# Conflicts appear; jj doesn't stop
jj st                                    # see conflicted files
jj resolve                               # or edit files directly
jj squash                                # merge resolution into conflicted commit
# Descendants auto-rebase; may resolve their conflicts too
```

### Multiple Working Directories (Workspaces)

Unlike Git, jj supports multiple working directories (like `git worktree`) via workspaces:

```bash
jj workspace create ../feature-a-workspace -r feature-a
jj workspace create ../feature-b-workspace -r feature-b
# Now you can work on both simultaneously in different directories
# Each workspace has its own working copy commit
jj workspace list                        # see all workspaces
jj workspace remove ../feature-a-workspace
```

Workspaces are independent; edits in one don't affect the other. Useful for long-running parallel work or comparing implementations side-by-side.

## Pitfalls & Gotchas

1. **No staging area.** Edits are live in `@`. If you want to "stage" something, make a new change with `jj new` and move files there.

2. **Bookmarks don't auto-advance when you create child commits.** Unlike Git branches that move forward with each commit, jj bookmarks stay put when you `jj new` on top of them. Use `jj bookmark set <name>` to move them manually, or pass `-b <name>` to `jj new` to create a new change AND point the bookmark at it in one step.

3. **Change ID vs Commit ID.** `jj log` shows both. Change ID (letters) is stable across rewrites; commit ID (hex hash) changes. Prefer change IDs in commands.

4. **Conflicts are stored, not blocking.** A rebase can succeed with conflicts. You resolve them later. This is intentional.

5. **`jj undo` is powerful.** It undoes any operation, not just commits. Use `jj op log` to see what you can undo.

6. **`jj git push` vs `jj git push --tracked`.** The former pushes the current bookmark if it's tracked; the latter pushes all tracked bookmarks.

7. **Revset syntax is strict.** `main..feature` works; `main .. feature` (with spaces) may not. Quote complex revsets: `jj log -r 'main::@'`.

8. **Working copy is always a commit.** Even if it's empty. `jj st` shows it. Don't try to "check out" files like Git.

## Config (Minimal)

```toml
# ~/.config/jj/config.toml
user.name = "Your Name"
user.email = "you@example.com"

# Set default editor
ui.editor = "vim"

# Set default diff editor for interactive commands
ui.diff-editor = ":builtin"              # or "meld", "kdiff3", etc.

# Aliases
aliases.s = ["status"]
aliases.l = ["log", "--no-pager"]

# Git-specific
git.push-bookmark-prefix = "user/"       # auto-prefix pushed bookmarks
```

## When to Use What

| Situation | Use |
|---|---|
| Start a new feature | `jj new main -b feature-name` |
| Fix a bug in current work | `jj desc -m "fix: ..."`, keep editing |
| Realize parent needs a fix | `jj new @-`, fix, `jj squash -i` |
| Reorder commits | `jj rebase -r <rev> -o <new-parent>` |
| Combine multiple commits | `jj squash` (or `jj squash -i` for selective) |
| Split a commit | `jj split` |
| Discard everything | `jj restore` |
| Undo last command | `jj undo` |
| Push to GitHub | `jj git push -b <bookmark>` |
| Pull from GitHub | `jj git fetch` |

## Resources

- Official docs: https://docs.jj-vcs.dev/
- Tutorial: https://docs.jj-vcs.dev/latest/tutorial/
- Steve Klabnik's tutorial: https://steveklabnik.github.io/jujutsu-tutorial/
- Jujutsu for everyone (no Git experience needed): https://jj-for-everyone.github.io
