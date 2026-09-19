---
name: nix-remote-build-live-diagnosis
description: "Diagnose a live Nix build that runs on a remote or emulated builder: where the sandbox is and why it is root-only, why make -n in it is not safe, the empty-log signature of a cancelled build, why a client exit restarts a derivation from zero, which probes are honest, and the pv bar traps. Use when a build is running elsewhere and you must say whether it is progressing, nearly done, or dead."
---

# Reading a live Nix build that runs on a remote builder

Use when a build you wait on runs on another machine (or emulated) and you must
answer "still working, nearly done, or dead?" without root on the builder.

## Where the build actually is

- Client: the `nix build` / `nixos-rebuild` process. It prints one line per
  derivation, nothing per file.
- Builder: the daemon creates one sandbox per build at
  `/nix/var/nix/builds/nix-<pid>-<rand>/` **on the builder**.
  - `<sandbox>/build/` holds `env-vars` (the stdenv export list: `PATH`, `CC`,
    `CROSS_COMPILE`), `source/` (the unpacked tree) and compiler temp files.
  - Out-of-tree Kbuild: `<sandbox>/build/source/build/` is the `O=` directory
    with `.config` and `include/config/auto.conf`; the objects live under it.
  - The sandbox is mode 700 root, so as a normal user `ls` and `stat` fail.
    The chroot is `/nix/store/<drv>.chroot`.
- Object count, read-only and safe at any time:
  `sudo find <sandbox>/build/source/build -name '*.o' | wc -l`.

## Never run make in that tree

`sudo make -C <root> -n …` is not read-only. GNU make executes recipes that
contain `$(MAKE)` even under `-n`, to propagate the flag into sub-makes, so a
"dry run" starts real sub-makes in a tree a live build owns. It also expands
`$(shell $(CC) --version)` probes, which fail or mis-count unless the sandbox
`env-vars` is sourced. If you must, source `env-vars`, keep it to one line and
`nice -n 19` it; better, do not, and use the object count instead.

## Logs

- The builder writes `<logdir>/xx/<rest>.drv.bz2` only when the derivation
  **ends**. While it runs, `nix log <drv>` prints nothing.
- The live log streams to the **requesting client**. Without
  `-L` / `--print-build-logs` the client discards it and shows it only on
  failure. Start long builds with `--print-build-logs`; that file is the only
  live progress you get.
- A 0-byte `.drv.bz2` with a fresh mtime is the signature of a **cancelled**
  build.

## Cancellation: the client owns the build

- A build is cancelled when the client that requested it exits. The derivation
  then restarts from zero. Signature: a new `nix-<pid>-<rand>` sandbox with a
  handful of objects, a fresh `.chroot` mtime, an empty drv log.
- A second client does not protect the build: the build belongs to the
  requester, and the survivor merely re-requests it, which starts it over.
- So run long builds as a durable client: a root systemd unit
  (`systemd-run --unit=… --property=StandardOutput=file:…`), never an ssh shell
  or an unaudited detached process.
- Root units hit two extra traps: libgit2 refuses a checkout owned by another
  user (`git config --global --add safe.directory <repo>`), and `--collect`
  unloads the unit on exit, destroying the `Result` / `ExecMainStatus` a later
  report wants. Add `systemctl reset-failed <unit>` before `systemd-run` so a
  re-run is not refused.

## Honest progress signals

- `pgrep -fc qemu-aarch64` on the builder: above zero means emulated work runs.
  Whole builds are emulated, so this covers compiles, `ld`, `make` and `sed`.
- `pgrep -af qemu-aarch64` argv names the running tool and its `-o` target,
  which reveals the phase: `.o` objects, then `vmlinux`, then `.ko`.
- Client side: `nix path-info` on the still-outstanding derivations is the
  authoritative finish signal, and a `--dry-run` that reports nothing to build
  means the closure is complete.
- Beware `pgrep -c ld`: the kernel threads `[kworker/R-kthrotld]` and
  `[kworker/R-mld]` match on the substring.
- Do not scale a snapshot of in-flight targets into a rate. A fixed number of
  concurrent processes is a concurrency floor, not completions per minute.

## pv bars on a build log

- pv is a pass-through: send its data output to `/dev/null`, or the data shreds
  the bar.
- Force the width (`-w 76`). pv otherwise sizes to the terminal, which in an
  attached tmux session can be wider than the pane showing it, so each update
  wraps and floods the scrollback.
- `-s N` is a hard cap: once the stream passes N, pv prints above 100% and the
  bar overflows. Guess generously, or leave the bar out.
- `-e` is only as honest as the guess; `-r` collapses during line-sparse phases
  (link, modpost, installkernel) and prints absurd ETAs; `-a` never recovers
  from an initial burst. `-p -t -r` without `-e` is the calm display.
- pv hides its display when stderr is not a tty, which makes captured runs look
  empty. It is often absent from the profile: `nix run nixpkgs#pv --`.

## Scripts that travel

The same path (`/tmp/x.sh`, `~/`, `~/.config/…`) usually exists on both hosts,
so a copy scp'd for one will happily run on the other. Put a guard at the top —
architecture, a required file such as `/etc/nix/machines`, the repository path —
and exit before any side effect.
