---
name: long-remote-build-observability
description: "Run and monitor a multi-hour remote-builder NixOS update (e.g. ASAHI built on NIXPC) without losing it: durable systemd unit client, why a client exit restarts the build from zero, the sentinel/watchdog split, a tailnet status page for phone monitoring, object-count progress semantics, and the nom and USER=root flavour traps."
---

# Long remote-builder updates: keep it alive, and make progress readable

Use when a multi-hour build runs on a remote builder (aarch64 host built on an
x86_64 box) and someone wants to know "how far along" while away from the
keyboard.

## 1. Client ownership: the hours you lose

A build belongs to the client that requested it. When that client exits, the
daemon cancels the build, writes an empty drv log, and the *next* waiter
re-requests the same derivation — from zero.

Evidence pattern (3.5 h lost once):

```sh
# ASAHI: the owning client is gone
pgrep -af 'nix build --impure'          # only the second client remains
# NIXPC: a fresh sandbox with ~10 objects, and an empty log for the drv
ls -l /nix/var/log/nix/drvs/4a/p9k…-linux-asahi-7.1.13.drv.bz2   # 0 bytes, new mtime
ls -t /nix/var/nix/builds/ | head -1
```

Rules that follow:

- Never start a second client for a derivation already in flight; it does not
  protect the build, and the death of either owner cancels it.
- Run the one client as a **root systemd unit**, never as a detached child of an
  ssh session.
- A plain `--no-link` build has no GC root until the switch creates the
  generation, so do not let a GC fire between "build finished" and "switch".

## 2. Durable client shape

```sh
sudo systemd-run --unit=HOST-rebuild \
  --property=StandardOutput=file:/tmp/HOST-rebuild.log \
  --property=StandardError=file:/tmp/HOST-rebuild.log \
  --property=OOMScoreAdjust=-800 \
  --setenv=USER=root --setenv=HOME=/root \
  --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going \
    --builders @/etc/nix/machines \
    --option builders-use-substitutes true \
    --print-build-logs --no-link "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel"
```

- **No `--collect`**: a transient unit is unloaded on exit, so a later
  `systemctl show -p Result` cannot say whether the build succeeded. Clean up
  with `systemctl reset-failed`, and do that on entry too or a second run dies
  with "Unit already exists".
- **`--print-build-logs`** is what makes the log usable; without it you see one
  line per derivation.
- **`--setenv=USER=root`**: a config that branches on `builtins.getEnv "USER"`
  (firmware paths) yields a *different* toplevel as a normal user. Root flavour
  is what `nixos-rebuild switch` evaluates, so a prebuild as another user is
  wasted work.
- **libgit2 safe.directory**: a root unit evaluating a checkout owned by another
  user dies with "repository path … is not owned by the current user". Fix once:
  `git config --global --add safe.directory <checkout>`.
- Put the whole thing in one idempotent script the user runs with `sudo bash`,
  and **guard it against the wrong machine** (`uname -m`, `/etc/nix/machines`,
  the checkout path) — the same script path on two hosts otherwise runs the
  wrong half and starts units on the wrong box.
- Kill stray clients without `procps` (absent from systemd's PATH): walk
  `/proc/[0-9]*/cmdline` with `tr`, and skip unreadable entries with
  `[ -r "$d/cmdline" ] || continue`.

## 3. Waking an agent when it ends

Delivery happens when a background job **exits**, so exiting is the wake-up.
Two watchers, not one:

- **sentinel mode** — loops until the report sentinel exists or the unit is no
  longer active; never exits on a stall heuristic. This is the only guaranteed
  finish notification.
- **stall mode** — separate job; exits after ~30 min of a flat log as early
  warning, labelled as a warning, not a verdict.

A flat log is normal: builder output is block-buffered and link/modpost steps go
quiet for many minutes. A false-positive exit in sentinel mode destroys the only
channel that reports the finish.

Also count consecutive failed status reads (~10) and exit on that: if the client
host suspends or the tailnet drops, the loop would otherwise never return and
the agent would never be told.

Sensor: one ssh call returning one line, e.g.

```sh
# on the client host
echo "$(wc -l <"$LOG")|$(systemctl is-active $UNIT)|$(test -f $SENTINEL && echo yes || echo no)|$(systemctl show -p Result --value $UNIT)|$(stat -c %Y "$LOG")|$(systemctl show -p ActiveEnterTimestamp --value $UNIT)"
```

Writer: a second unit that waits for the build unit to stop, writes a report
(log tail, `error` lines, a no-builder dry run) and finally touches the
sentinel. Independent of the agent session.

## 4. Readable from a phone

A stdlib python3 HTTP page that shells out to the sensor, binds the **tailnet
address only** (not `0.0.0.0`), auto-refreshes every 10 s, and shows:

- a banner: amber BUILDING, green `SUCCESS ✔ — the switch will build nothing`,
  red `FAILED ✘ — unit result: …`;
- the status age in seconds, and a red `NO ANSWER FROM <host> for Ns` banner
  when the fetch fails — otherwise a suspended machine and a quiet build render
  identically;
- the last known tail/compilers/paths so a stale page still says something.

Start it detached (`setsid nohup nix run nixpkgs#python3 -- server.py`) because
the omp hub broker is often down; open the URL in the user's real browser as an
app window (`brave --app=URL`), and verify with `wlrctl toplevel list`.

## 5. Progress semantics

- **Objects**: `sudo find <sandbox>/build -name '*.o' | wc -l`, with the delta and
  timestamp printed so the user can paste one line. Rate is ~40 objects/min under
  emulation; 60-second windows are the smallest honest sample.
- **Kbuild's module pass is three passes**: compile every `[M]` object, then one
  global `modpost`, then link `.ko`. So a `.ko` count stays **0** through the
  whole compile stage; the first `.ko` is the milestone, not a percentage.
  `modules.order` counts modules, not objects, so it cannot predict remaining
  object work.
- **Never run `make` in a live sandbox**: GNU make executes recipes containing
  `$(MAKE)` even under `-n`, so a "dry run" starts real sub-machines in a tree a
  live build owns. Read with `find`/`wc` only.
- Log lines are the weakest metric (bursty, and several per compile object);
  compiler count (`pgrep -fc qemu-aarch64`) plus the object count are stronger.
- `nom` must be the consumer of the nix command from the start
  (`nom build …`, or `nix … --log-format internal-json -v 2>&1 | nom --json`).
  Pointed at a `--print-build-logs` file it renders an empty tree while echoing
  tens of thousands of compiler lines.
- Offload check that cannot be faked: `grep "on 'ssh-ng://" log` for the
  positive, and the *client* host's load staying near zero while the builder's
  compiler count is high. A bare `building '…drv'` line also appears for remote
  builds, so `grep -v "on 'ssh-ng://"` is not a local-build detector.

## 6. Suspend and GC windows

- A laptop client with `HandleLidSwitch=suspend*` / `IdleAction=suspend*` freezes
  the build silently: no failure, no sentinel. Block it for the duration:
  `sudo systemd-run --unit=build-inhibit --collect systemd-inhibit --what=idle:sleep:handle-lid-switch --why="build" --mode=block sleep infinity`.
- Check the GC timer before an unattended window; a weekly `--delete-older-than`
  job landing in the unrooted gap collects the copied closure.
