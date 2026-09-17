---
name: jj-cli-automation-traps
description: "Drive Jujutsu (jj) from a script, daemon, or app: the CLI-subprocess contract, machine-readable output, credential inheritance, conflict/push/op-log semantics, and the working-copy-ownership trap where automation hijacks the user's live @. Use when building any jj automation, jj sync tool, or jj GitSync-style clone, or when jj commands behave unexpectedly under automation."
---

# Driving jj from automation

Facts verified against jj 0.45.x docs and source (`jj-vcs/jj`), 2026-09.

## Surface choice

jj's FAQ calls both surfaces unstable. Choose one and pin it.

- `jj-lib` (crates.io, 0.45.1; MSRV 1.97.1; now split with a `jj-core` crate): "not a stable API". The library cannot read the user's home config or env vars — by design, so a server or GUI can embed it.
- `jj` CLI subprocess: also unstable ("you may need your tool to detect the different versions"), but canonical. Use when you want zero build coupling and jj's own auth path for free.
- No REST/RPC, no `--json`. Machine-readable state is `-T/--template` with `json(value)`: `jj log -T 'json(self) ++ "\n"'` gives JSONL. `jj config get <name>` prints a raw scriptable value; `jj util config-schema` prints the JSON config schema.
- There is **no `ui.interactive` knob**. Non-interactivity is per command: `-m` for messages, `--no-edit`, and `jj converge --no-interactive`. Editor resolves as `$JJ_EDITOR > ui.editor > $VISUAL > $EDITOR`.

## Scripting baseline

```
jj -R <repo> --color=never --no-pager --quiet <cmd>
```

- `-R/--repository <path>` operates on another repo (no `cd` needed).
- `--ignore-working-copy` skips snapshotting; `--at-op <op>` implies it.
- Set `ui.paginate=false` or pass `--no-pager`; a pager on a pipe hangs a daemon.
- Exit codes are non-zero on error but are not formally documented — treat stdout/stderr text as advisory only, never parse error prose.
- Prefer `-T json(...)` output over human text for anything load-bearing.

## Networking: git is a hard dependency

`docs/git-compatibility.md`: "**Authentication: Yes.** `git` is used for remote operations under the hood." `lib/src/git.rs::fetch`/`push` go through `lib/src/git_subprocess.rs`; gitoxide (`gix`) handles the local object store and reading remote config/refspecs only. `MINIMUM_GIT_VERSION` = 2.42.0.

Consequences:

- Credential helpers, ssh config/keys, `GIT_ASKPASS` and `GIT_TRACE` work unchanged. **A wrapper tool needs no secret storage** — do not build a credential vault.
- Any self-contained deployment (Android APK, container, bundle) needs **both** a jj binary and a git binary for the target ABI. jj ships no Android artifact; Termux runs it only via `tur-repo` with documented `libssl.so.3` link errors. Take the jj/git binary path from config; never assume PATH or `/usr/bin`.

## The ownership trap (get this wrong and you eat user work)

`@` is a real commit and the working copy; nearly every jj command snapshots it first. So an automation loop that does `jj describe -m "auto"` + `jj new` on a repo the user is editing:

- overwrites the user's in-progress change description,
- inserts a commit boundary into their work,
- races the user's own concurrent jj commands (jj is lock-free and merges operations, which makes the damage silent rather than refused).

Decide explicitly, before writing the loop:

1. **Commit the user's live `@`** (GitSync-style — valid when the folder is app-owned, e.g. a phone vault).
2. **Operate on a dedicated change/workspace** the tool owns (`jj workspace add <dest>` → per-device workspaces), leaving the user's `@` untouched.

Related: `jj git fetch` can **abandon commits no longer reachable on the remote and replace the working-copy commit**; disable with `git.abandon-unreachable-commits=false` if the tool must not move user state.

## A sync cycle in jj terms

There is no index and no "current branch". A push needs a bookmark pointing at a commit that is not yet on the remote.

- Cycle: snapshot (implicit) → `jj describe -m <msg> @` → `jj bookmark move <name> -t @` → `jj git push --bookmark <name>` → `jj new` (fresh empty change, or `--no-edit` to leave `@` alone).
- Which bookmark? There is no current bookmark. Either a configured name, or auto-detect `heads(::@ & bookmarks())` / tracked-remote bookmarks. Never create a bookmark implicitly on a user's repo.
- Nothing to push? `@` with no changes means empty change: skip describe and push.
- Divergence: no pull, no merge-on-fetch. `jj git fetch` moves `<name>@origin`; if that is not an ancestor of `@`, push refuses (force-with-lease-like). The idiom is `jj rebase -s @ -o <name>@origin`, then abort if the rebase leaves a conflict.
- Conflicts are **first-class and recorded in commits**; the operation still succeeds. Push refuses conflicted commits unless `--allow-conflicts` (also `--allow-empty-description`, `--allow-private`).

## Transactionality via the operation log

Every command is an operation and each operation stores a repo view, so:

```
jj op log -T 'json(self) ++ "\n"' -n 5    # find the pre-run op id
jj op restore <op-id>                      # roll the repo back exactly
jj undo / jj redo                          # one step
```

Record the pre-run op id before mutating, and `jj op restore` on failure to get an all-or-nothing cycle. Restoring also discards a fetch that already landed — that is the intended trade (safe, repeatable) but state it, and offer a report-only mode.

## Colocated repos

`jj git init`/`clone` are colocated by default (`.git` beside `.jj`; jj imports/exports on every command). Docs list the costs: interleaved mutating `git` commands cause branch conflicts and divergent change ids; IDEs running background `git fetch` trigger this unknowingly; a large ref count slows every jj command (`jj util gc` mitigates); git tools see conflicted commits as `.jjconflict-*` directory noise. Prefer read-only git commands next to jj, and convert with `jj git colocation enable|disable|status`.
