---
name: omp-long-nix-build
description: "Run a multi-hour Nix build from an omp session without losing it: the 300 s bash-tool deadline that silently kills a backgrounded build, async + timeout 0, why hub start fails when the omp broker is dead, and the reachability check a nix copy needs. Worked example: the ASAHI bootchain, which has no upstream cache and builds on the Mac itself."
---

# Long Nix builds from an omp session

Multi-hour derivations (kernels, chromium, the Asahi bootchain) need three
things this harness does not give by default: no deadline, a live client, and a
reachable destination.

## 1. The deadline kills the build, not just the call

`bash` with `async: true` still applies the tool deadline (default 300 s). The
job is reported as `[Command timed out after 300 seconds] error: interrupted`,
and **the Nix build restarts from zero** on the next attempt — partial compile
state is never reused.

Set `timeout: 0` together with `async: true`:

```
bash: async=true, timeout=0
cd <flake> && nix-store --realise <drv>... > /tmp/build.log 2>&1
```

Progress comes from reading the log (`builtins.readFile` via `nix eval --raw`,
or the `read` tool): the phases run patch → configure → `make` → install, so
`HOSTLD scripts/kconfig/conf` means the compile has not started.

Do not rely on `hub start` for this when the broker is dead: it fails with
`Failed to start daemon broker at ~/.omp/run/daemons/<hash>/broker.sock`.
A detached client is not a fix either — the Nix daemon cancels an in-progress
build when its requesting client disconnects. Keep one long-lived client.

## 2. A push copy needs the destination reachable first

`nix copy --to ssh-ng://da@<host> …` waits on the ssh connection, so an offline
or asleep destination shows up as a multi-minute hang, not an error. Check
before copying:

```sh
tailscale status | head -3          # look for "offline, last seen …"
nc -zv -w 5 <ip> 22                 # expect "succeeded"
```

Untested candidate: when the peer is only reachable over the tailnet, a hang
may come from tailscaled's SSH server rather than OpenSSH (Nix defaults to a
multiplexed `ssh -M -N` master). The LAN address of the same host reaches the
real sshd and is worth trying — confirm with the small-path probe below.

Probe the delivery path with one tiny store path before pushing gigabytes:

```sh
nix copy --to ssh-ng://da@<host> /nix/store/<tiny-path>
ssh da@<host> nix path-info /nix/store/<tiny-path>   # must be valid
```

## 3. Worked example: the ASAHI bootchain

The bootchain has no upstream cache, so an `asahi` input bump builds it on the
Mac — `nixos-apple-silicon.cachix.org` covers the rest of the flake but not
`linux-asahi` / `uboot-asahi` / `m1n1`. It is the long pole of an ASAHI
rebuild: a run reaches `0/537` only once the kernel compile starts.

That build takes the whole box. `max-jobs = 4` with `cores = 0` in
`modules/hosts/ASAHI/asahiConfiguration.nix`, so the kernel runs `make -j8`
natively on 8 vCPU. It was previously pinned to `max-jobs = 1; cores = 1`
because earlyoom kept SIGTERM'ing a multi-GiB rustc; earlyoom is retired and
forced off, and zram at 100% plus an 8 GiB `/swapfile` is the memory policy.
Memory is the limit to respect, not core count — see
`skill://dendritic-local-rebuild` for the rebuild itself.

If anything is ever built on another machine again, decide what is transferable
by the **drv path**, not the output name: an identical drv path means an
identical output, a different one means the derivation is hardware-dependent and
must build on the Mac. Measured on this repo (`linux-asahi` 7.1.13):
`linux-asahi` and `linux-asahi-modules` matched across hosts, while
`-modules-shrunk` and `initrd-linux-asahi` did not — the initrd embeds
`/boot/vendorfw`, which exists only on the Mac.
