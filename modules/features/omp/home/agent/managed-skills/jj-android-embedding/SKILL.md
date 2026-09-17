---
name: jj-android-embedding
description: "Plan or debug driving Jujutsu (jj) from an Android/mobile app: what the APK must ship (jj binary, git binary only for network ops), why a SAF tree cannot host .jj, cross-compile route, and the git2-rs + jj git import reconciliation pattern."
---

# Driving jj from an Android app

Verified against jj 0.45.1 (2026-09) source and docs. Re-verify before relying on version-specific lines.

## What jj actually needs at runtime

- **No git binary for local work.** Snapshot, `describe`, `new`, `bookmark`, `rebase`, `squash`, `log`, `op log`, `git import/export` all go through gitoxide (`GitBackend`). A jj on PATH-less Android does local jj work fine.
- **git binary is required only for:** `jj git fetch`, `jj git push`, and clone into a populated directory (`lib/src/git.rs` constructs `GitSubprocessContext` in exactly those paths — fetch ~line 3274, `push_refs` ~3450, `push_updates` ~3564, worktree add ~1873).
- **The version check is lazy, not a startup gate.** `MINIMUM_GIT_VERSION = "2.42.0"` (`lib/src/git_subprocess.rs:50`) appears only inside an error message string; there is no `--version` probe at CLI startup. So "no git installed" fails only when a remote operation runs — an app can therefore ship jj alone and do the network itself.
- **git is not used for the object store**, so a colocated `.git` (written by gix) stays valid without the git CLI.

## Routes for network access on Android

1. **git2-rs (libgit2) for fetch/push, jj for local ops.** Precedent: GitSync cross-compiles git2-rs for aarch64/armv7/x86_64/i686 with https+ssh and uses it as its whole engine. After a libgit2 push, jj's view must be reconciled: update the local remote-tracking ref (`refs/remotes/<remote>/<bookmark>`) to the pushed commit, then run `jj git import` so `main@origin` and jj's push-tracking state agree. Costs one cross-compiled binary (jj, pure Rust via cargo-ndk).
2. **Bundle a git binary too.** Faithful to desktop behavior but means an autotools build (openssl, zlib, curl) per ABI, or a prefabricated static build.
3. Keep both behind a `RemoteTransport` trait so the choice stays swappable.

## Storage: a jj working copy needs a real path

- `.jj` needs POSIX paths, real mtimes for `TreeState::snapshot`, and file locks. **A SAF tree URI cannot be a jj working copy** — cloud-backed Documents trees are out for the repo root.
- GitSync's route: `MANAGE_EXTERNAL_STORAGE` plus real paths (`/storage/emulated/0/Documents/<vault>`), which is what lets an Obsidian vault be shared with the app. Play restricts all-files access but GitSync ships on Play, so approval is attainable.
- Alternatives: app-specific external dir (no permission, invisible to other apps), or app-private repo + SAF mirror (adds a copy step and loses live working-copy semantics).

## Install/version facts

- jj produces **no Android artifact**; docs' `community_tools.md` lists no mobile front-end.
- Termux runs jj only via `tur-repo` with known `CANNOT LINK EXECUTABLE` / `libssl.so.3` issues needing `LD_LIBRARY_PATH=$PREFIX/lib`.
- `jj-lib` and `jj-core` are published (0.45.x) but the docs call the API unstable; CLI is the canonical integration surface and is also unstable — pin and detect versions.

## Machine-readable state without a JSON API

No `--json` flag. Use templates: `jj log -T 'json(self) ++ "\n"'` (JSONL), global `json(value)` and `String.escape_json()`. Global flags worth always passing when shelling out: `--color=never --no-pager --quiet`, `-R <path>` for out-of-tree repos, `--ignore-working-copy` to avoid a snapshot, `--config name=value` for per-call overrides. There is **no `ui.interactive` knob**; non-interactivity comes from `-m`, `--no-edit`, `--no-interactive` on `jj converge`.

## Safety primitives worth designing around

- Every command is an operation with a stored repo view → an atomic all-or-nothing sync cycle is possible via `jj op restore <op-id>`.
- `jj git fetch` can abandon unreachable commits and replace the working-copy commit; `git.abandon-unreachable-commits=false` disables that.
- Push is force-with-lease-like: it refuses non-fast-forward bookmark moves and refuses conflicted commits without `--allow-conflicts`.
- `@` is a real commit: `jj describe @` rewrites the commit the user is editing. Any syncer that auto-describes must either own the folder or gate on an empty description.
- Conflicts are recorded in commits rather than failing the operation, so a "no conflict" check must be explicit.
