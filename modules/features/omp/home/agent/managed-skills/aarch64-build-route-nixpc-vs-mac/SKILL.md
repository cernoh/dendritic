---
name: aarch64-build-route-nixpc-vs-mac
description: "Measure the qemu-aarch64 emulation penalty and pick native Mac vs NIXPC emulated for ASAHI/aarch64 builds: the same-store-path gcc A/B recipe, the 15x result on this pair, the serial-bootchain check, forcing and proving \"all local\", the two-clients-on-one-drv-set lock trap, and the earlyoom budget."
---

# Which host should compile an aarch64 build

Hardware pair: **NIXPC** (x86_64, Ryzen 3700X, 16 threads, runs the aarch64 work under
`binfmt`/qemu-user) and **ASAHI** (Asahi Mac, aarch64 M1, 8 cores, ~7.5 GiB RAM,
`max-jobs = 1; cores = 1` in `modules/hosts/ASAHI/asahiConfiguration.nix` for earlyoom reasons).

## The measurement that decides it

Emulation penalty is large enough to invert the architecture choice, so measure it instead of
assuming. Use **the same store-path compiler** on both hosts and one CPU-bound source file:

```sh
GCC=/nix/store/<hash>-gcc-15.3.0/bin/gcc        # exists on both hosts: same nixpkgs target
BIN=/nix/store/<hash>-binutils-2.46/bin         # raw gcc needs the matching `as` on PATH
run() { s=$(date +%s%N); PATH=$BIN:$PATH $GCC -O2 -c /tmp/bench.c -o /tmp/o.o; e=$(date +%s%N); echo $(( (e-s)/1000000 )) ms; }
```

Generate `/tmp/bench.c` as ~400 float-heavy functions (no includes beyond math.h) so one compile
is seconds, not milliseconds. Measured 2026-09-22 on this pair:

| where | compiler | time |
|---|---|---|
| NIXPC, aarch64 gcc via binfmt | emulated | 14.6 s |
| ASAHI Mac, same store path | native | 1.24 s |
| NIXPC, x86_64 gcc | native | 0.96 s |

⇒ **penalty ≈ 15×**. NIXPC's 16 emulated threads are worth ≈1 real core; the idle Mac's 8 cores win
even at `-cores 2..3`. Do not use `/usr/bin/time` (absent on both NixOS hosts); the raw `gcc-15.3.0`
store path fails with `as: unrecognized option '-EL'` unless the aarch64 binutils dir is on PATH.

## Before re-routing, read the plan and the graph

- Remaining work: `nix build --dry-run --impure .#nixosConfigurations.ASAHI.config.system.build.toplevel`
  on the Mac (as the same user, `--impure`, same checkout). The bootchain remainder is ~11
  derivations: `linux-asahi` → `-modules` → `-modules-shrunk` → `v4l2loopback`/`initrd` → `boot.bin`,
  `copy-extra-files`, `systemd-boot`, `install-systemd-boot.sh`, `boot.json` → toplevel.
- That is one **serial chain**, so `max-jobs`, machine slots and cross-derivation parallelism are dead
  levers. Confirm with the client's own TUI (`∑ ⏵ 1 │ ⏸ 10`) and with one live sandbox on the builder.
- Kernel `-j` is not a lever either: `nix derivation show <linux-asahi>.drv` exposes `structuredAttrs`
  (env holds only `dev/modules/out`), where `enableParallelBuilding = true`, `makeFlags` has
  `O=$(buildRoot) --eval=undefine modules`, `buildFlags` has `Image vmlinux … modules dtbs`, there is
  no custom `buildPhase`, and `requiredSystemFeatures = ["big-parallel"]`. The generic stdenv phase adds
  `-j${NIX_BUILD_CORES}`; with the builder's `cores = 0` that is `-j16` (evidence: 62–69 qemu processes
  during the CC/DTC phase). `make … prepare` is the serial configurePhase.

## Forcing and proving "all local"

Empty builders is the only reliable switch, and it can be set two independent ways:

```sh
export NIX_CONFIG='builders ='          # does not depend on nh forwarding unknown args
nix build … --builders '' --max-jobs 1 --cores 3
```

Proof recipe (a flag alone is not proof):

- the build line is plain `building '/nix/store/…drv'` and **never** `on 'ssh-ng://…'`;
- on the builder: `pgrep -c qemu-aarch64` = 0 and no `nixbld*` process;
- on the client: no `nix __build-remote` / `ssh remotebuild@… nix-daemon --stdio`;
- `--cores 3` has no such tell — `cores = 1` in the client's nix.conf can win silently, which would
  make the native reroute worthless (1 native core ≈ 16 emulated at 15×). Check the compiler count
  (`pgrep -c cc1` ≈ cores) or put `cores = 3` in `NIX_CONFIG` too.

`nh` 4.4.2 (store path from a logged-in pane's `/proc/<shell>/environ`, not from a non-interactive
`bash -s`) supports `nh os build . -H ASAHI --impure -- <extra nix build args>`; nom's TUI is built in
(no `nom` binary needed), and `--dry` still runs a real build with no builder override.

## Traps that cost real time here

1. **Two clients on one drv set.** A `--dry` (or otherwise abandoned) client keeps its goal and the
   kernel's `/nix/store/<out>.lock` files, so the new client sits at `waiting for lock on
   '/nix/store/…-linux-asahi-7.1.13'` with `∑ ⏵ 0` and nothing progresses. Kill both the `nh`/`nix
   build` client **and** its `nix-daemon <pid>` child, then re-verify.
2. **`nh` as the user is the neutral eval flavour.** `onMacAsRoot` in the ASAHI config keys off
   `getEnv "USER"`, so `nh` run as `da` produces the "neutral" toplevel (no peripheral-firmware
   extraction); a `sudo` switch produces the other one. Match the flavour of the client you are
   replacing, or the work is thrown away.
3. **Killing a client cancels its in-flight derivation** (finished ones stay). Keep a durable client
   (tmux window in the user's session or a root unit) and surface the sunk cost before restarting.
4. **earlyoom on the Mac** (`-m5 -r3600 -s5`, ~375 MiB free, i.e. `MemAvailable`-based): run the
   bootchain at `--max-jobs 1 --cores 3`, watch `MemAvailable`/`SwapFree`; a kill is recoverable
   because completed derivations are cached — retry at `--cores 2`. Brave commonly holds ~2.5 GiB of
   the 7.5 GiB; closing it is the cheapest headroom.
5. **Read the sandbox dir**: the live build's chroot appears in the store as
   `<drv path>.chroot` with a fresh mtime, and `/nix/var/log/nix/drvs/**/*.bz2` is root-only, so
   `nix log <drv>` returns nothing while the build runs. The client's TUI pane is the only live view.

## One-liner for a live local build in the user's tmux

```sh
tmux new-window -t 0: -n native-build 'env USER=da bash /home/da/asahi-nh-build.sh'
tmux pipe-pane -t 0:native-build -o 'cat >> /tmp/asahi-nh-build.pane.log'   # keeps the TUI, records it
```

Script body: `export PATH=<nh bin dir>:$PATH; export USER=da; export NIX_CONFIG='builders =';
nh os build . -H ASAHI --impure -- --builders '' --max-jobs 1 --cores 3`, then write the rc to a file
and `touch` a sentinel so a remote watcher can report completion and count `on 'ssh-ng` occurrences.
