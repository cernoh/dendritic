---
name: nix-long-build-client-ownership
description: "Diagnose and prevent a multi-hour Nix build restarting from zero: the requesting client owns the build, an exiting client cancels it, setsid is not durable (use a root systemd unit), how to read the failure (empty drv log + missing client pid + fresh sandbox), the sandbox layout, and safe read-only progress probes. Use when a long build seems to reset, when a build's outputs never appear, or before probing a live build sandbox."
---

# A long Nix build restarted from zero

## Fact 1: the requesting client owns the build

A build belongs to the client that requested it. If that client process exits
(crash, OOM kill, closed ssh session, `Ctrl-C`, harness timeout), the daemon
**cancels** the build. Another client waiting on the same derivation does not
save it: the survivor simply re-requests, so the derivation starts over.

Three signals read together prove a cancel-and-restart:

1. a fresh tmpdir `/nix/var/nix/builds/nix-<pid>-<rand>` whose mtime is minutes
   old while the derivation has been requested for hours;
2. that tmpdir's object count is tiny (tens) instead of the thousands the dead
   attempt had;
3. the derivation's log file `/nix/var/log/nix/drvs/<2>/<rest>.drv.bz2` is
   **0 bytes** with a timestamp equal to the restart. A cancelled build leaves
   an empty log; a failed build leaves output.

Count the clients before believing anything else:

```sh
ssh <requester> "pgrep -af 'nix build'"
ssh <builder>   "ls -t /nix/var/nix/builds/ | head -3; pgrep -c qemu-aarch64"
```

Two clients on one derivation are worse than one: the smallest noise restarts
the build. Keep exactly one, and keep it out of the shell that might die.

## Fact 2: `setsid`/`nohup` is not durable; a root systemd unit is

`setsid nohup nix build ... &` survives the ssh disconnect but not an OOM kill
of the client, and it captures no exit status or log. The durable form, one
sudo password entry:

```sh
sudo systemd-run --unit=BUILD --collect \
  --property=StandardOutput=file:/tmp/BUILD.log \
  --property=StandardError=file:/tmp/BUILD.log \
  --setenv=USER=root --setenv=HOME=/root --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going --print-build-logs \
    /path/to/flake#attr
```

`--print-build-logs` matters: it is the only way to read progress and failures
afterwards, because a plain client discards the log stream. `systemctl stop
BUILD` cancels; killing the unit does not.

On the requester, also protect the client from the OOM killer if the host is
memory-capped (`OOMScoreAdjust=`), and check for an earlyoom kill:

```sh
journalctl -b | grep -iE 'earlyoom|killed process'
```

## Fact 3: never run a build tool inside a live sandbox

A NixOS build sandbox looks like this:

```
/nix/var/nix/builds/nix-<pid>-<rand>/build/env-vars   # stdenv export list
                                        /build/source # unpacked source root
/nix/store/<drv>.chroot                               # sandbox root
```

For an out-of-tree build the config and objects are not in `source/`: look for
`source/build/.config` and `source/build/include/config/auto.conf`, and every
`.o` under that `build/` dir.

**Do not run `make` there, not even `make -n`.** GNU make executes recipes that
contain `$(MAKE)` even under `-n` (to pass `-n` down), so a "dry run" starts
real sub-makes in a tree a live build owns, with the wrong toolchain and as
root. Symptoms: `gcc: No such file or directory` from `make[2]`, a plan of a
few lines, and a count that claims everything is done.

Safe, read-only probes of a live build:

```sh
sudo find /nix/var/nix/builds/nix-<id>/build -name '*.o' | wc -l   # objects so far
pgrep -c <emulator>                                               # busy? e.g. qemu-aarch64
pgrep -af <emulator> | sed -n 's/.* -o \([^ ]*\).*/\1/p' | tail -3 # current target
```

Object *counts* are the only honest per-object progress. Object *names* seen in
`ps` churn (assembler temporaries like `ccXXXXX.s`), so never count them; and a
`make -n` denominator is not worth the risk it carries.

## Fact 4: verify on the requester, not the builder

The requester can always answer "is it done" without touching the sandbox: for
each remaining derivation, ask whether its output path is valid locally.

```sh
for d in <drv paths>; do
  for p in $(nix-store -q --outputs "$d"); do
    nix path-info "$p" >/dev/null 2>&1 && echo "present $p" || echo "missing $p"
  done
done
```

Filter secondary outputs (`-dev`, headers) that the system closure never asks
for, or they stay `missing` forever and read as a stall. Gate the conclusion on
the toplevel output specifically. The output path flips to present at the exact
moment the copy back from the builder lands, so this doubles as the completion
signal.
