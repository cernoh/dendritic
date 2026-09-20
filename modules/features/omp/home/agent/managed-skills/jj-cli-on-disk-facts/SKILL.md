---
name: jj-cli-on-disk-facts
description: "Measured facts about the jj CLI's on-disk behaviour when designing an app that drives it (a vault sync, an Android client, a data model over a jj repo): no repo identity, the op log as a change journal, when a read writes, exit-code classes, kill recovery, GC that needs a git binary, and per-cycle growth — with the probe commands to re-measure. Use before designing storage, status, history or recovery over a jj repo."
---

Measured on **jj 0.45.1**, host x86_64, 2026-09-19, against scratch colocated repos (`jj git init`).
Re-measure with the commands below before trusting any number; jj is unstable and these are
version-specific. Worked example: the `jjsync` data-model ticket.

## 1. A jj repo has no identity of its own

```bash
jj git init /tmp/a && jj -R /tmp/a op log --no-graph -T 'self.id() ++ "\n"' | tail -1
```

The oldest operation is the **all-zero null id in every repo**, so the op log cannot key a repo,
and the newest id changes with every operation. A colocated repo points at its objects through
`.jj/repo/store/git_target` (`../../../.git`), so blobs live in `.git/objects`, not under `.jj`.

**Consequence:** an app keyed on "the repo" must generate its own id; store the path and the
remote URL as locators, never as keys.

## 2. The op log is a change journal, not an observation log

| Action | Operations added |
|---|---|
| Two `jj status` on a clean tree | 0 |
| External edit, then the first `jj` command | 1 (the snapshot) |
| Any further read, incl. `--ignore-working-copy` | 0 |

So reads are effectively free, and the id advances only when the working copy really changed.
An operation record (`jj op log -n 1 -T 'json(self)'`) carries `id`, `parents`, `time.start`,
`time.end`, `description`, `hostname`, `username`, `is_snapshot`, `workspace_name`, and
`attributes.args` (the command that ran).

**Consequence:** the id answers "has the vault changed", and *cannot* answer "has another app
edited a file since the last snapshot". A freshness stamp needs the id plus a read time plus a
snapshot flag (or a `--ignore-working-copy` read will look fresh forever).

## 3. Reads can write; `--ignore-working-copy` is the opt-out

jj snapshots the working copy at the start of every command, so the first read after an external
edit writes one operation into the user's repo. `--ignore-working-copy` suppresses both the
snapshot and the working-copy update.

**Consequence:** decide explicitly which reads may mutate the repo (typically: opening a repo,
and a sync cycle) and pass the flag everywhere else.

## 4. Exit-code classes for repo health

Measured without a pipe (a `| head` makes `$?` report `head`):

| State | jj says | exit |
|---|---|---|
| healthy | normal output | 0 |
| `.jj` absent | `Error: There is no jj repo in "."` + a `jj git init` hint | 1 |
| `.jj` present, `.git` absent | `Internal error: The repository appears broken or inaccessible` | 255 |
| store type written by a newer jj | `Internal error: This version of the jj binary doesn't support this type of repo` | 255 |
| `jj -R <missing path>` | `Error: There is no jj repo in "<path>"` | 1 |

1 is jj's clean "not a repo here" answer; 255 is its internal-error class. Together with the
message, that is enough to classify a repo without touching the filesystem beyond an existence
check — and it makes format drift (a newer desktop jj) a distinguishable state rather than a
crash.

## 5. A killed process leaves locks; the vault heals itself

```bash
# 30k files, then kill jj mid-snapshot
jj status & pid=$!; sleep 0.35; kill -9 $pid
find .jj -iname '*lock*'      # .jj/working_copy/working_copy.lock, .jj/repo/git_import_export.lock
jj status                     # exit 0, normal output, re-snapshots; the stale files are gone
```

**Consequence:** a crash needs a repair step for the *app's* record of the run, not for the repo.
Persist a run-start marker with no end and read it as `interrupted`, never as `still running`.

## 6. Garbage collection cannot run without a git binary

```bash
env PATH=<dir with only jj> jj util gc
# Internal error: Unexpected error from backend / Failed to run git gc command / No such file or directory

env PATH=<dir with only jj> jj --config git.abandon-unreachable-commits=false util gc   # same failure
env PATH=<dir with only jj> jj op abandon ..<old-op-id>                                # works
```

`--expire now` does not help either. `jj util gc --help`: obsolete objects and operations older
than two weeks are pruned by default, and the help tells you to `jj op abandon` first. The same
git dependency already covers `jj git clone`, `fetch` and `push`.

**Consequence:** an app that ships no git binary can prune its operation store but not its object
store; the alternative routes are a bundled git, a libgit2-side prune, a periodic re-clone, or a
growth cap with a manual compact action that the user can see.

## 7. Growth caused by a sync cadence

50 cycles of "append a line, `jj describe`" in a one-file repo:

| Store | Before | After |
|---|---|---|
| `.jj` | 4,362 B | 136,719 B |
| `.git` | 14,233 B | 48,017 B |
| operations | 6 | 106 |

≈ **3.3 KB per changed cycle** (mean operation file 301 B, mean view file 124 B). At an hourly
edit cadence that is tens of MB a year in a real vault, and the app's own describe-and-amend
cycle is what creates it. Measure per-change sizes on a real vault before quoting a cap.

## 8. Cost and JSON shapes

Every `jj` call is a process spawn: ~14 ms on the host, warm cache, for `jj log -r @`,
`jj op log -n 1`, `jj status`, `jj bookmark list` — so per-repo calls on a list render add up, and
a device spawn is much slower than the host's.

- `jj log -r @ -T 'json(self)'` → `commit_id`, `parents`, `change_id`, `description`, `author`,
  `committer`.
- `jj op log -n 1 -T 'json(self)'` → as in §2.
- `jj bookmark list --all-remotes -T 'json(self)'` → `name`, `remote`, `target`,
  `tracking_target` (per remote; the local entry omits `remote`).
- `jj workspace list -T 'json(self)'` → `name`, `target`.
- `jj resolve --list` prints `Error: No conflicts found at this revision` when clean.

## 9. Device labelling and identity

jj exposes `operation.hostname` and `operation.username` (config keys), and the record already
carries both plus `workspace_name`. They come from the OS, so on Android they are absent or
meaningless: an app that wants the op log to say which device did the work must pass those two
keys on every invocation. Separately, with nothing configured jj warns
`Name and email not configured` and commits carry an empty identity, so an app must pass
`user.name`/`user.email` with `--config` if it creates commits.

## Measurement traps that cost cycles

- Quote templates: `-T json(self)` unquoted is a shell syntax error, and a timing loop then
  reports absurdly fast "results".
- Never read `$?` after a pipe (`jj … | head` reports `head`); redirect and test separately.
- A tiny scratch repo makes every command look instantaneous; do not extrapolate a device's
  process-spawn cost from it.
- Keep the two scratch repos separate when testing identity: reusing one hides whether an id is
  per-repo or per-content.
