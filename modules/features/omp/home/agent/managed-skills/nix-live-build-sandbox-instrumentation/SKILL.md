---
name: nix-live-build-sandbox-instrumentation
description: "Instrument and survive a multi-hour Nix build: the live sandbox layout for reading progress, why make -n is unsafe inside someone else's tree, pv bar calibration, a durable root-systemd client that keeps its exit status, and host guards for scripts copied to two machines."
---

# Instrumenting a live Nix build from outside

Context: a multi-hour build (e.g. `linux-asahi` for aarch64) is running through
one host's `nix-daemon`, the work happens on another host as a remote builder,
and somebody keeps asking "how far are we". These are the signals that exist,
the ones that lie, and the ways to destroy the build by accident.

## Sandbox layout (where the numbers live)

A running build's private tmpdir is `/nix/var/nix/builds/nix-<pid>-<rand>/`,
mode `700` root. Everything inside is invisible to a normal user, including
`stat` on the child `build` directory. Inside:

```
<nix-<pid>-<rand>>/build/
  env-vars      # the stdenv export list: PATH, CC, HOSTCC, CROSS_COMPILE, NIX_*
  source/       # the unpacked source tree (named after the unpacker's sourceRoot)
  ccXXXX.s      # gcc -pipe temporaries pile up here
```

Out-of-tree Kbuild puts the config and objects under an `O=` directory inside
the source tree, so `<source>/Makefile` has no `.config` beside it and
`make -C <source>` alone cannot compute anything:

```
<source>/build/.config
<source>/build/include/config/auto.conf
<source>/build/<mirrored kernel tree>/*.o
```

The whole tmpdir disappears the moment that derivation ends, so any path you
write down is stale within hours. Locate the live one first:

```sh
sudo ls -t /nix/var/nix/builds/ | head        # newest = live, others are stale
sudo ls /nix/var/nix/builds/nix-<id>/build/   # env-vars, source/, cc*.s
```

## Progress signals, best to worst

1. **Object count, read-only.** Safe at any time:
   `sudo find <source>/build -name '*.o' | wc -l`. It only rises. A first
   `linux-asahi` attempt reached 10,530.
2. **Phase from the compiler fleet.** The whole build is emulated, so
   `pgrep -af qemu-aarch64` shows every tool (cc1, as, ld, make, even sed).
   Read the last `-o` argument: `.o` files = object sweep, `vmlinux` = link,
   `CC [M]` lines in the log = module pass (the second big wave), `modpost` =
   module finish.
3. **Log lines, once the client has `-L`/`--print-build-logs`.** Without it the
   client prints one line per derivation and there is *no* progress to read;
   the daemon keeps the log until the drv ends, so `nix log <drv>` is empty
   while it runs, and the builds tree is unreadable.
4. **Client-side load.** A remote build leaves the requesting host idle
   (loadavg ~0.0). Load rising there means work fell back to local.

## Never run `make` in a live sandbox

GNU make executes recipes that contain `$(MAKE)` **even under `-n`**, to pass
the flag to sub-makes. A kernel tree is recursive make everywhere, so a
"read-only dry run" starts real sub-makes in a tree that a live build owns.
Symptoms if you try: `make[2]: gcc: No such file or directory`, config files
regenerated under the running build's feet, `make[1]: *** [...: .config]`.

If you want the denominator (`make -n ... vmlinux modules`, counting `-o *.o`),
do it only after the build ends, or on a copy, and inside the sandbox
environment rather than the host's:

```sh
sudo bash -c 'set -a; . /nix/var/nix/builds/nix-<id>/build/env-vars; set +a;
  exec /nix/store/<hash>-gnumake-4.4.1/bin/make -C <source> O=<source>/build \
    -n ARCH=arm64 vmlinux modules'
```

`ARCH=arm64` is mandatory: without it the top Makefile takes `SUBARCH` from
`uname -m` and evaluates the host architecture graph, returning a large
meaningless number. `make` is usually **not** in a NixOS system profile
(`command -v make` fails, `sudo make` is not found because of sudo's
`secure_path`); use the store path.

## pv bars that do not lie

- pv is a pass-through: `... | pv ... >/dev/null` or the data lines shred the bar.
- pv sizes the bar to the **terminal** width, which in tmux is the window, not
  the pane showing it: force `-w 76` or the bar wraps on every update and floods
  the scrollback.
- `-s N` is a guess; when the stream passes N the bar saturates at >100% and the
  number stops meaning anything. Re-baseline instead of just raising N.
- Drop `-e` (ETA). ETAs from a guessed total collapse to absurd values exactly
  during quiet phases (link, modpost), which is what makes people believe a
  12-hour figure. `-p -t -r` gives bar, elapsed and recent rate with no lie.

## Owning the build: the client, not the daemon, holds it

Nix cancels a build when the client that requested it goes away, and an
interrupted build restarts from zero. Two clients do **not** protect it: the
derivation belongs to its requester, and when that one exits the other simply
re-requests it and starts over. Evidence to look for: an empty
`/nix/var/nix/log/nix/drvs/<xx>/<rest>.drv.bz2` written at the moment of the
restart, a fresh `nix-<newpid>-<rand>` tmpdir, and `building '<drv>'` appearing a
second time in the client log.

Use a root systemd unit as the client:

```sh
sudo systemd-run --unit=DRV-build \
  --property=StandardOutput=file:/tmp/DRV.log \
  --property=StandardError=file:/tmp/DRV.log \
  --property=OOMScoreAdjust=-800 \
  --setenv=USER=root --setenv=HOME=/root \
  --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going \
    --print-build-logs --no-link '<flake>#<attr>'
```

- **Do not add `--collect` if you want a post-mortem.** A transient unit is
  unloaded the instant it finishes, so `systemctl show -p Result -p ExecMainStatus`
  then returns empty and nothing can say whether it succeeded. Keep the unit,
  read the status, clean up later with `systemctl reset-failed DRV-build`.
- `-L`/`--print-build-logs` is what turns the unit log into a real, watchable,
  pv-able stream. A bare `building '<drv>'` line without `on '<builder>'` is
  nix printing the per-derivation header *in addition* to the offload event —
  not a local build. Judge locality by the requesting host's loadavg and by the
  builder's `pgrep -c cc1` / qemu fleet, never by that grep.
- A root unit evaluating a checkout owned by another user hits libgit2's
  "repository path is not owned by the current user": run
  `git config --global --add safe.directory <repo>` as root first.

## Notifying an agent session when it ends

Two independent channels:

1. Machine side: a report unit (`systemd-run --unit=…-report`) that waits
   `until ! systemctl is-active --quiet <build unit>`, writes a report file
   (unit `Result`, exec status, log tail, error lines, a no-builders dry run),
   then `touch`es a sentinel.
2. Agent side: a poller in the session that ssh-checks the sentinel every
   minute and prints the report when it appears. Give its ssh calls
   `-o ServerAliveInterval=15 -o ServerAliveCountMax=4`, or a stalled link hangs
   the loop silently and the notification never fires.

## Guarding scripts that live on two machines

`/tmp/x.sh` written on host A and scp'd to host B exists on both, so "run
/tmp/x.sh" is ambiguous and can land on the wrong machine. Make the script
refuse: check `uname -m`, a machine-specific path (`/etc/nix/machines`), and the
target's home directory *before* any action, and print where it is instead.
Also `systemctl reset-failed <unit>` on entry, so a second run does not die with
"Unit <unit>.service already exists".

## Remote shells that are not POSIX

Probe with `ssh host /run/current-system/sw/bin/bash -l < local-script` rather
than `ssh host 'a=$(...); ...'`. A fish login shell rejects `a=$(...)`, breaks
multi-line `for` loops, and splits pasted commands at wrapped lines, so
results look like "the command printed 0" when in fact nothing ran.
