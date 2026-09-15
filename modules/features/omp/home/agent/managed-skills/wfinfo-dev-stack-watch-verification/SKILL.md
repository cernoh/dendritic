---
name: wfinfo-dev-stack-watch-verification
description: "Design and verify a concurrent-watch flake dev app (frontend live reload + backend rebuild-on-edit) in WFinfo-ext: the trap/wait -n wrapper, the dotnet-watch restart-vs-hot-reload proof, the inotify probe that must append (touch fires nothing), and isolated WFINFO_DATA_DIR testing. Use when adding or auditing a nix run .#dev-* app, or when dotnet watch seems not to re-run."
---

# Concurrent-watch dev app in WFinfo-ext

Extends the user skill `wfinfo-flake-run-apps` (read that first for the
`program = "${writeShellScriptBin ...}/bin/<name>"` trap, working-tree vs store
copy, `meta.description`, and the Bun.spawn "verify without hub" pattern).
This skill covers the case that skill does not: an app that runs TWO watchers.

## When

- Adding `nix run .#dev-all`-style apps (frontend + backend together).
- Auditing whether a `--watch` loop actually does anything on this filesystem.
- A reviewer or agent claims the watch is dead because `inotifywait` saw nothing.

## Wrapper shape (proven)

```sh
set -eu
root="${WFINFO_DEV_ROOT:-$PWD}"
# guard: test BOTH -f "$root/headless/WFInfo.Headless.csproj" and -f "$root/dashboard/src/main.ts"
export PATH="<makeBinPath devTools pkgs>:$PATH"
cd "$root"

pids=()
stop() { trap - INT TERM EXIT; kill "${pids[@]}" 2>/dev/null || true; wait 2>/dev/null || true; }
trap stop INT TERM EXIT

dotnet watch --project headless/WFInfo.Headless.csproj run -- --scan --no-notify "$@" &
pids+=($!)
deno run -A --watch dashboard/src/main.ts &
pids+=($!)
wait -n
```

- `devTools pkgs = scanTools pkgs ++ [ pkgs.deno ]` (scanTools already pulls
  `dotnet-sdk_9 grim wlr-randr libnotify`).
- Pass `--no-notify` in the dev stack: one toast per edit is noise. Keep
  `nix run .#scan` as the notifying path.
- Both watchers must see the working tree, so resolve the checkout from `$PWD`
  (a store copy can never reload). Same reason as `.#dev` in the user skill.

## The dotnet-watch trap (decisive)

`dotnet watch` prints **"Hot reload enabled"** for a console program. That
banner is misleading: hot reload does not rerun a program that already
**exited**. The runner exits after each `--scan`, so watch arms, then
**restarts** on the next edit. Do not "fix" anything based on the banner.

Prove a real re-run with an observable side effect, not the log:

1. Start the stack with `WFINFO_DATA_DIR` on a COPY of the data dir.
2. Wait for the first `scans/latest.json` to exist; record its `mtimeMs`.
3. Append a line to a `.cs` file under `headless/`.
4. Poll `mtimeMs > scan1` for up to ~180 s.

Passing log sequence:

```
[WFInfo.Headless (net9.0)] Exited
⏳ Waiting for a file to change before restarting ...
⌚ Building .../WFInfo.Headless.csproj ...
Warframe Info — reward screen scan      <- new record written
```

## inotify probe: append, never touch

`touch` fires NO `modify` event (it only updates times). A first probe built on
`touch` returns event-less and looks like "watch is dead on this mount". The
conclusive probe appends:

```sh
inotifywait -m -e modify,close_write --format '%e' headless/    # background
printf '\n// probe\n' >> headless/Program.cs                     # then revert
```

Expected on this NTFS3 (`fuse`/`ntfs3`) mount: `MODIFY` then
`CLOSE_WRITE,CLOSE`. Proven working, so no `DOTNET_USE_POLLING_FILE_WATCHER=1`
is needed.

## Test isolation (mandatory)

Never point a dev-stack test at the live app-data dir. Copy it first:

```sh
rm -rf /tmp/<x>-data && mkdir -p /tmp/<x>-data
cp -a ~/.config/WFInfo /tmp/<x>-data
# then run with WFINFO_DATA_DIR=/tmp/<x>-data and a free PORT (8231, 8799, ...)
```

The wrapper honors `WFINFO_DATA_DIR`, so scan records land in the copy. Verify
by the dashboard's own line: `data dir: /tmp/<x>-data/WFInfo`.

If you DO clobber `~/.config/WFInfo/scans/latest.json`, restoring it changes
**mtime** even though content matches the prior record. Report it as "content
restored, mtime updated by the restore", not "untouched" — and prove it with
`cmp` against the newest `scan-*.json`.

## Do not kill other sessions' processes

A leftover `deno run -A dashboard/src/main.ts` may belong to a concurrent agent
session, not you. Identify before touching:

```sh
ps -o pid,ppid,lstart,cmd -p <pid>
readlink /proc/<pid>/cwd
tr '\0' '\n' < /proc/<pid>/environ | grep '^PORT=\|^WFINFO'
ss -ltnp | grep <pid>
```

Different `PORT` / `WFINFO_DATA_DIR` / cwd = not yours. Leave it and report.
Never `pkill -f` a pattern that could match someone else's daemon.

## Cleanup

`jj workspace forget <name>` then `rm -rf ../<ws>`; remove `/tmp/<x>-data`;
confirm no probe residue with
`diff <(git show <bookmark>:<file>) <ws>/<file>`, and `pgrep -af` for leftovers.
In the main checkout, check `git status --short <path>` is empty before telling
the user the tree is clean — a concurrent session may have added files.

## STE delta lint (measure only your prose)

Linting whole docs re-reports pre-existing violations. Extract only added lines,
and use `> `, NOT `^+[^+]` (the latter eats the first character of every line and
splices fragments into fake long sentences):

```sh
diff base.md new.md | sed -n 's/^> //p' >> /tmp/added.md
ste-lint.py < /tmp/added.md
```
