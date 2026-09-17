---
name: omp-long-nix-build
description: "Run a multi-hour Nix build or remote prebuild from an omp session without losing it: the 300 s bash-tool deadline that silently kills a backgrounded build, async + timeout 0, why hub start fails when the omp broker is dead, and the reachability check that a push copy needs. Worked example: prebuilding the ASAHI bootchain on NIXPC."
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

## 3. Worked example: the ASAHI bootchain on NIXPC

The bootchain has no upstream cache, so an `asahi` input bump builds it. Use the
*drv path* to decide what is transferable: identical drv means identical output,
different drv means hardware-dependent and must build on the Mac.

Verified 2026-09-16 on both hosts (`linux-asahi` 7.1.13):

- identical → prebuild on NIXPC and copy: `linux-asahi-7.1.13`,
  `linux-asahi-7.1.13-modules`
- different → leave to the Mac: `-modules-shrunk`, `initrd-linux-asahi-7.1.13`
  (the initrd embeds `/boot/vendorfw`, which exists only on the Mac)

Sizes: the ASAHI toplevel wants 802 derivations built on NIXPC's plan, 537 on
the Mac, and the kernel is the long pole — a run reached `0/537` only when the
kernel compile started. Emulated on NIXPC the kernel runs `make -j16` under
qemu-user instead of the Mac's `-j1`.

Do not "speed up" the Mac by raising `cores`: 8 GiB RAM plus earlyoom is why
`max-jobs = 1; cores = 1` is set there, and an OOM kill after an hour costs more
than the wait.

Related: `skill://dendritic-asahi-cross-build` (the link itself, host keys,
trusted-users, and the trust/round-trip proof).
