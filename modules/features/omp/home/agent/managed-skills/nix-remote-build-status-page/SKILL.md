---
name: nix-remote-build-status-page
description: "Watch a multi-hour remote Nix build (ASAHI built on NIXPC) from a phone: a supervised status page with cached ssh refresher and staleness banner, sentinel-only plus stall watchers that wake the agent, and the traps — nom cannot parse --print-build-logs output, Tailscale SSH re-auth kills monitoring ssh while the build keeps running, HTTPS-First rewrites http://IP, pv caps at its -s guess."
---

# Watching a long remote build without lying to the user

Context: a NixOS toplevel for ASAHI (aarch64) built on NIXPC (x86_64) through
`--builders @/etc/nix/machines`. Hours long, run as a root systemd unit so no
session can cancel it. The user watches from a phone and must not be told
"fine" while the build is frozen.

## What the monitored side actually is

- The *client* lives on ASAHI (`nix build`, or a root unit `ASAHI-rebuild`).
- The *work* happens on NIXPC, inside a sandbox owned by that machine's daemon.
- The build's own traffic runs over the tailnet with the `remotebuild` key, so
  it survives a broken *monitoring* path (proved useful — see traps).
- The requester's exit cancels every build it requested. A second client does
  not protect a build; it recreates the failure mode (one client dying restarted
  a 3.5 h kernel build from zero).

## Health signals, weakest last

1. `pgrep -fc qemu-aarch64` on the builder. 70-85 while compiling; 0 means the
   compile stage is over *or* nothing is building. The single best local signal.
2. Tailnet peer counters as an ssh-free proof the link is alive:
   `tailscale status | sed -n '/<peer>/p'` twice, 30 s apart. Growing tx/rx means
   the builder and client are talking, so the build is progressing.
3. Object count in the sandbox (`find <sandbox> -name '*.o' | wc -l`) — needs
   root on the builder; deltas over >=60 s give objects/min.
4. Log line count on the client: liveness only. Output is block-buffered, so it
   is flat for minutes and then jumps; a short sample reads anywhere from
   0 to 80 lines/min. Never quote it as a rate.
5. `modules_linked` (`*.ko`) stays 0 through the entire module compile stage,
   because Kbuild compiles every object, then runs modpost, then links. The first
   `.ko` is the "endgame" milestone, not steady progress.
6. `modules.order` (line count) is the module total for the config but cannot
   predict remaining object work.

## Traps that cost real time

- **nom is for the next build.** It must be the consumer of the nix command from
  the start (`nom build …`, or `nix … --log-format internal-json -v |& nom`). Given
  a `--print-build-logs` file it renders an empty tree and echoes the compiler
  lines; on a real log, 3000 consecutive lines were *all* build output. Never
  point it at a running unit's log, and never start a second client to get it.
- **Tailscale SSH re-auth**: `ssh da@<host>` over Tailscale SSH can start
  returning `# Tailscale SSH requires an additional check. # To authenticate,
  visit: https://login.tailscale.com/a/…`. Monitoring dies while the build keeps
  running (it uses plain ssh + a key, other direction). Check tailnet counters
  before believing the build is in trouble, and ask the user for one URL visit.
- **HTTPS-First**: browsers rewrite `http://<ip>:8765` to `https://` and fail —
  there is no TLS. `http://127.0.0.1:8765/` is exempt, so bind `0.0.0.0` and hand
  the localhost URL to the desktop, the tailnet URL to the phone.
- **pv caps at its `-s` guess** and its instantaneous rate collapses in quiet
  link steps, producing the bogus "12 hours" ETA the user will quote back at you.
  Use `-w 76 -p -t -r` (fixed width, no `-e`) or drop pv entirely.
- **A wrong-machine script**: an identical `/tmp/<name>.sh` on two hosts invites
  running it on the wrong one. Guard on `uname -m` plus the presence of the
  files it needs, and print a clear refusal before touching anything.
- **Absolute make, never a dry run in a live tree**: GNU make executes recipes
  containing `$(MAKE)` even under `-n`, so a "dry run" starts sub-makes in a tree
  another build owns. For counters, use read-only `find`/`wc` only.

## The page (recipe)

- One Python stdlib file, `ThreadingHTTPServer` on `0.0.0.0:8765`.
- A **background refresher thread** does all ssh work every ~15 s and writes into
  a dict; request handling only renders that dict. Requests must never block on
  ssh, or a stalled link freezes the page.
- Show `status age` and switch the banner to a red `NO ANSWER FROM ASAHI for Ns`
  when the status is older than ~120 s, keeping the last known details visible.
  A frozen host and a quiet build must not render identically.
- Health line, driven by the signal that still exists during a monitoring outage:
  `HEALTHY — N compilers`, `NO COMPILERS — quiet link step or module pass done`,
  `N compilers … but ASAHI's status cannot be read`. Local compilers need no ssh.
- Terminal states explicitly: green `SUCCESS ✔ — the switch will build nothing`
  (only when the sentinel exists *and* the unit result is `success`) versus red
  `FAILED ✘ — unit result: …`, plus the report text.
- **Supervise it**: a loop script that restarts the server and appends to a log,
  started with `setsid nohup`. Keep the `pkill` patterns *inside* the launcher
  file — on the command line they match the launching shell and kill it.
- Verify by fetching with `/dev/tcp` and grepping the markup for the banner; a
  text extractor drops styled `<div>` banners, so check the raw HTML too.

## Watchers (how the agent gets woken)

Exiting is the delivery mechanism, so:

- Run **two** watchers. `sentinel` mode never exits early: only the sentinel or a
  non-active unit ends it. `stall` mode adds early warning after ~30 min of a
  flat log and is explicitly labelled a warning, since buffered output looks the
  same.
- Never let a stall heuristic terminate the sentinel watcher, and never let the
  ssh-failure branch retry forever: after ~10 consecutive failed reads, alert and
  exit (that is the wake-up for "machine asleep / off the tailnet").
- The report and sentinel are written by a second unit on the target that waits
  for the build unit to go inactive, so completion is reported even if the
  agent's own watcher is broken.

## Handing over to the user

- Build unit, then `sudo systemd-inhibit … sleep infinity` if the target can
  suspend (`HandleLidSwitchExternalPower=suspend` and
  `IdleAction=suspend-then-hibernate` both freeze a unit silently).
- One-command restart on the target for a dead unit; the report file for the
  post-mortem; `-w 76` bars; the localhost URL for the desktop.
