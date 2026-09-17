---
name: jj-automation-integration
description: "Drive Jujutsu (jj) from another program — CLI subprocess vs jj-lib, machine-readable -T json templates, non-interactive flags, auth via jj's git subprocess, and the missing Android target. Use when building any tool, daemon, or app that automates jj."
---

# Automating jj from another program

Facts verified 2026-09 against jj main docs + 0.45.1 (2026-09-03).

## Pick the surface

| Surface | State | Use when |
|---|---|---|
| `jj` CLI subprocess | unstable CLI, canonical | default choice |
| `jj-lib` crate (crates.io 0.45.x, MSRV 1.97.1, now split with `jj-core`) | "not a stable API" | Rust tool, can pin crate version |
| `-T/--template` JSON | field names/types "usually stable", not guaranteed | machine-readable state |
| REST / RPC / FFI | **does not exist** (roadmap only: `jj api`, forge submits) | — |

`docs/faq.md` states plainly that neither the CLI nor the lib is stable; pin a version
and detect it at runtime. jj's own recommendation for git-custom backends is the CLI.

**No `--json` flag.** Use templates: `jj log -G -T 'json(self) ++ "\n"'` → JSONL.
`json()` exists for Serialize types: `Commit`, `Operation`, `String`, `Bookmark`/`RefSymbol`,
`Signature`, `RepoPath`. `jj config get <name>` prints a raw scripting-friendly value;
`jj util config-schema` prints the config JSON schema.

## Non-interactive scripting

- No `ui.interactive` knob exists. Non-interactivity is per command.
- Authoring: `-m <msg>` and `--no-edit`; `jj commit -m` = describe + new; `jj converge --no-interactive` is the only such flag.
- Global flags: `-R/--repository <path>`, `--ignore-working-copy`, `--at-operation/--at-op`,
  `--ignore-immutable`, `--color=never`, `--quiet`, `--no-pager`, `--config NAME=VALUE`,
  `--config-file <path>`, `--no-integrate-operation` (prints resulting op id).
- Exit codes are not formally documented; assume non-zero on error.
- Editor chain `$JJ_EDITOR > ui.editor > $VISUAL > $EDITOR`; pager `ui.pager`/`JJ_PAGER`/`ui.paginate`.

## Concepts a git-centric tool must map

- Working copy **is** a commit (`@`); parent `@-`. No index, new files auto-tracked (`snapshot.auto-track`).
- Change ID survives rewrites; commit ID is the git id. Change offset `xyz/0` disambiguates.
- Bookmarks ≈ branches; remote bookmarks are `<name>@<remote>`; one local bookmark can track
  several remotes and names must match; there is **no current bookmark**.
- Conflicts are recorded **inside commits** and the operation still succeeds. Push refuses
  conflicted commits unless `--allow-conflicts`.
- Push is force-with-lease-like and refuses to move a bookmark backwards.
- `jj git fetch` abandons commits unreachable on the remote and may replace the working-copy
  commit — disable with `git.abandon-unreachable-commits=false`.
- Operation log gives `jj undo`, `jj op restore/revert <op>`; `--at-op` loads old state.
- Colocated repos (`.jj` + `.git` siblings, the default from `jj git clone`) auto import/export
  every command; `jj git import/export` are no-ops there unless `--ignore-working-copy`.

## Auth and remotes

jj runs **the real `git` binary** for fetch/push (`lib/src/git_subprocess.rs`), forcing
`LC_MESSAGES=C`, `stdin=null`, `stderr=piped`. So git credential helpers, ssh config/keys and
`GIT_*` env vars (documented hook: `GIT_ASKPASS`, `GIT_TRACE`, injected in `lib/src/git.rs`) work
unchanged. Requires **git >= 2.42.0**. Only two git config items are read:
`[remote "<name>"]` refspecs and `core.excludesFile`. Known gap: jj cannot install new
`credential.helper` entries (jj issue #4101).

Key commands: `jj git clone <src> [dst] [--colocate|--no-colocate] [--depth n]`,
`jj git remote add|set-url|list|remove|rename`,
`jj git fetch [--remote r] [-b branch] [-t tag] [--all-remotes]`,
`jj git push [--remote r] [-b|--bookmark n] [--all] [--tracked] [--deleted] [-r revset] [--dry-run] [--allow-new?] [-o git-opt]`,
`jj bookmark create|set|move|delete|forget|track|untrack`,
`jj new [-m msg] [--no-edit]`, `jj describe -m`, `jj squash`, `jj absorb`,
`jj rebase -s|-b|-r <revs> -o|-A|-B <revs>`, `jj workspace add <dest> [--name n]`.

## Platform limits

No official Android build, no Play/F-Droid app, no mobile frontend in `docs/community_tools.md`.
Termux has jj only via TUR (`tur-repo`), with `CANNOT LINK EXECUTABLE libssl.so.3` history
(TUR #2052, needs `LD_LIBRARY_PATH=$PREFIX/lib` + openssl/zlib). Prebuilt assets exist for
darwin/msvc/linux-musl x86_64+aarch64 only. **Consequence: a mobile app can never shell out to a
system jj; it must bundle a jj binary (cargo cross-compile) — and since jj itself spawns git for
fetch/push, it needs a bundled git too.**

## Verification recipe

Before relying on any jj automation, prove the flags on the pinned version:

```bash
jj --version
jj -R /tmp/probe log -r '@' --no-graph --color=never -T 'json(self) ++ "\n"'
jj -R /tmp/probe bookmark list --all-remotes --color=never -T 'json(self) ++ "\n"'
jj -R /tmp/probe git push --dry-run --color=never    # no ref changes, proves auth path
```
