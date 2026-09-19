---
name: asahi-overnight-remote-build
description: "Run an unattended multi-hour ASAHI (aarch64 Mac) NixOS build with NIXPC as remote builder and watch it from a phone: durable systemd client, USER=root eval flavour, libgit2 safe.directory, the two-client restart trap, endgame metrics (MODPOST/.mod.o/.ko), report sentinel plus two watchers, and a tailnet status page."
---

# Unattended ASAHI build on the NIXPC remote builder

Worked end to end on 2026-09-19: kernel 7.1.13 built remotely, 14:54 → 01:57, clean exit.

## The client owns the build, so make it durable

A `nix build` client that exits cancels every derivation it requested. Observed
cost: one of two detached clients died at 14:36, the daemon wrote a zero-byte
`/nix/var/log/nix/drvs/4a/<kernel>.drv.bz2`, the surviving client re-requested
the derivation a moment later, and 3.5 h of emulated kernel compile restarted
from zero (35 MB of `.o` files gone with the sandbox).

Run one client, as a systemd unit, and never a second one:

```sh
systemd-run --unit=ASAHI-rebuild \
  --property=StandardOutput=file:/tmp/ASAHI-rebuild.log \
  --property=StandardError=file:/tmp/ASAHI-rebuild.log \
  --property=OOMScoreAdjust=-800 \
  --setenv=USER=root --setenv=HOME=/root --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going \
  --builders @/etc/nix/machines --option builders-use-substitutes true \
  --print-build-logs --no-link \
  /home/da/.config/dendritic#nixosConfigurations.ASAHI.config.system.build.toplevel
```

- No `--collect` on the build unit: systemd unloads a transient unit on exit and
  `systemctl show -p Result` then reports nothing, which is the field the report
  needs.
- `--print-build-logs` gives a real log to grep; without it the client prints one
  line per derivation and there is no per-file progress at all.

## Two traps that cost hours

1. **`USER=root` decides the evaluation flavour.** ASAHI's config reads
   `getEnv "USER" == "root"` to decide whether to include the peripheral
   firmware. As `da` the toplevel drv is `0jrl0sb98p3…`; as root it is
   `pw00rpsw7a8j…`. A prebuild in the wrong flavour is wasted work, because
   `sudo nixos-rebuild switch` evaluates the root flavour. The unit runs as root
   *and* sets `USER=root`; a user-level `nix run … nom build …` needs
   `env USER=root`.
2. **libgit2 refuses a checkout owned by another user.** A root systemd unit
   evaluating `/home/da/.config/dendritic` dies with
   `repository path … is not owned by current user (libgit2 error code = 7)`.
   Fix once, before starting anything: `git config --global --add safe.directory
   /home/da/.config/dendritic` (idempotent check with `--get-all | grep -qx`).
   A unit started without `HOME` does not read that config, so set
   `--setenv=HOME=/root` on any unit that evaluates the flake.

## Stop stray clients without procps

`pkill` may be absent from the daemon PATH and `|| true` hides that, so scan
`/proc` and report the count: `for d in /proc/[0-9]*; do [ -r "$d/cmdline" ] ||
continue; cmd=$(tr '\0' ' ' <"$d/cmdline" 2>/dev/null) || continue; case "$cmd"
in *"nix build --impure"*) kill "${d#/proc/}" 2>/dev/null && n=$((n+1));; esac;
done`. Expect to stop exactly one client, and print the number so a silent miss
is visible.

## Reading progress on the builder

- `pgrep -fc qemu-aarch64` on the builder: 70-85 while compiling, ~6 during the
  final link steps, 0 when done. The whole build is emulated, so this is
  throughput, not object progress.
- `find <sandbox> -name '*.o' | wc -l` for the object count. Both need root: the
  sandbox is `drwx------ root`.
- The endgame, from the log alone: `MODPOST` appears **once**; then `.mod.o`
  lines climb to the module count; then `LD [M]` lines link the `.ko` files; the
  first `.ko` in the sandbox means the compile stage is over.
- The distributed module denominator is the running kernel's installed modules
  (`*.ko*` under `lib/modules/<ver>/kernel`), 7,797 for 7.1.12; the build
  produced 7,798, so it is a usable target.
- `modules.order` in the build tree is the exact module count for the config, but
  it exists only after modpost — reading it earlier returns an empty file.

## Notifications and the page

Exiting is the only way a background watcher's message reaches the session, so
never let a heuristic be the *only* channel:

- **sentinel mode** exits only when the report sentinel exists or the unit is not
  active — the guaranteed finish notification;
- **stall mode** exits after 30 min of a flat log, as early warning, and says so;
  buffered builder output looks identical to a stall.
- After ~10 consecutive ssh failures, exit with a NO ANSWER alert. Whether ASAHI
  is awake is otherwise invisible.

The report unit waits for the build unit (`until ! systemctl is-active`), then
writes the log tail, greps `^error`, and touches the sentinel. There is a
deliberate ~1 minute window where the build unit is inactive and no sentinel
exists yet; inside it, judge success by `systemctl show -p Result` and by the
toplevel path being valid, not by the missing sentinel.

A phone-friendly status page is worth it: a stdlib Python server binding
`0.0.0.0:8765`, refreshing its data in a background thread at most every 15 s
(ssh to ASAHI throttles rapid parallel starts) so requests never block, showing a
colour banner, a health line, the compiler count and the endgame numbers, and a
supervisor loop that restarts it. Staleness must be visible: stamp each fetch and
switch the banner to NO ANSWER when it is old, or a suspended host looks exactly
like a quiet build.

In Brave, `http://<tailnet-ip>:8765` fails: HTTPS-first rewrites it to `https://`
and there is no TLS. Use `http://127.0.0.1:8765/` on that machine; localhost is
exempt. A cache-busting `?v=$(date +%s)` is needed when re-opening a window that
loaded during a server restart, because an error page has no meta-refresh.

## Do not point nom at an existing log

`nix-output-monitor` is excellent for the *next* build (`nom build …`, or
`nix build --log-format internal-json -v … |& nom --json`), but it cannot consume
a `--print-build-logs` file: measured, the last 3,000 lines of such a log were
all `drv> …` build output, so nom renders an empty tree while echoing tens of
thousands of compiler lines.

## Final verification before telling the user to switch

- `nix path-info` on each of the plan's remaining output paths (13 here) and on
  the toplevel out path — all present means the switch builds nothing;
- the derived check is a no-builder `nix build --dry-run`, run where its error
  text is visible (a report that only greps the plan lines drops the error and
  proves nothing);
- keep the host awake for the copy-back: ASAHI is on battery with
  `IdleAction=suspend-then-hibernate` / `IdleActionSec=10min` and
  `HandleLidSwitch=suspend-then-hibernate`, so an idle Mac or a closed lid
  freezes the client. Either keep the lid open or
  `systemd-inhibit --what=idle:sleep:handle-lid-switch --mode=block sleep infinity`;
- a `--no-link` build leaves the copied closure unrooted until the switch, so run
  the switch before the next GC timer (`systemctl list-timers nix-gc.timer`).
