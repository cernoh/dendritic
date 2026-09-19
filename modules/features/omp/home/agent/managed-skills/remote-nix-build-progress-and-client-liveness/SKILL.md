---
name: remote-nix-build-progress-and-client-liveness
description: "Keep a multi-hour remote NixOS rebuild alive and measure its progress honestly: the client-exit cancellation trap and the durable root systemd unit, the builders flag the first switch needs, which signals mean what (qemu fleet, object count, modules.order, .ko), never running make in a live sandbox, and the pv/nom pitfalls."
---

# Long remote Nix build: keep it alive, measure it honestly

Applies when a host builds through a remote builder (here: ASAHI/aarch64 offloaded to
NIXPC/x86_64 through `ssh-ng://remotebuild@<ip>`) and the build runs for hours.

## 1. One build belongs to one client. A client exit throws the work away

A `nix build` client owns the derivations it requests. When that client exits, the daemon
cancels them, and Nix does **not** resume an interrupted derivation: the next client that
wants it starts it from zero.

Observed cost: the kernel derivation reached 10,530 compiled objects over 3.5 h, its owner
pid disappeared, the daemon wrote a 0-byte drv log, and a surviving second client that also
wanted the derivation restarted it from scratch. Two clients do **not** protect a build;
the build still belongs to the first requester.

Diagnosis of that case: (a) `pgrep -af 'nix build'` on the client host shows which clients
still exist; (b) a zero-byte `/nix/var/log/nix/drvs/<2>/<rest>.drv.bz2` timestamped at the
restart moment means a cancelled attempt; (c) a freshly created sandbox with a small object
count versus a large abandoned one proves the restart.

Fix: run the client as a root systemd unit, so no shell, ssh session, or dying detached
process can cancel it. Add `--print-build-logs` so there is a real log to read.

```sh
sudo systemd-run --unit=HOST-rebuild \
  --property=StandardOutput=file:/tmp/HOST-rebuild.log \
  --property=StandardError=file:/tmp/HOST-rebuild.log \
  --property=OOMScoreAdjust=-800 \
  --setenv=USER=root --setenv=HOME=/root --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going \
    --builders @/etc/nix/machines --option builders-use-substitutes true \
    --print-build-logs --no-link /home/USER/config#nixosConfigurations.HOST.config.system.build.toplevel
```

Do **not** pass `--collect` on that unit: systemd unloads transient units the moment they
finish, and then `systemctl show -p Result -p ExecMainStatus` returns empty, so a watcher
cannot tell success from failure. Clean up later with `systemctl reset-failed HOST-rebuild`.

A root unit evaluating a checkout owned by another user hits libgit2's ownership check. Add
the directory to root's git config first (idempotent), or run the unit with `--uid=USER
--setenv=USER=root` to keep ownership while still taking the root eval branch.

## 2. The first switch needs `--builders`, later ones do not

Current nixpkgs (`nixos/modules/config/nix-remote-build.nix`) only nulls the setting when
`nix.distributedBuilds = false`. With it `true` the setting is left alone, and Nix's
compiled default for `builders` is `@$NIX_CONF_DIR/machines`, i.e. `@/etc/nix/machines`.

Verify on the machine, with an empty config dir:

```sh
NIX_CONF_DIR=$(mktemp -d) NIX_USER_CONF_FILES=/dev/null nix config show builders
# expect: @<tmpdir>/machines
```

Consequence: a running generation that renders `builders = ` (empty) ignores
`/etc/nix/machines`, so its first switch compiles everything locally. Pass the machines file
for that one run; the generation it activates then consults the file by default.

```sh
sudo nixos-rebuild switch --impure --flake /path#HOST \
  --builders '@/etc/nix/machines' --option builders-use-substitutes true
```

Preconditions to check once, not to assume: the builder advertises every feature the
derivations require (`system-features`; `big-parallel` is load-bearing for linux-asahi,
while `kvm`/`nixos-test` must not be advertised), the builder's `trusted-users` contains the
ssh account, the pinned base64 host key equals `base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub`
on the builder, and the requester's private key exists at the `sshKey` path.

## 3. Which progress signal means what

Ranked, best first:

1. `pgrep -fc qemu-aarch64` on the builder. The whole build is emulated, so every tool
   (cc1, as, ld, make, sed) is a qemu process. 70-85 means compiling; 0 with the unit still
   active means a quiet phase (link, modpost, copying) or a stall.
2. The unit's log with `--print-build-logs`. It shows `building '…' on 'ssh-ng://…'` per
   derivation plus the build output. Note both a bare `building '…'` line and the
   `on 'ssh-ng://…'` line appear per derivation; the bare one is not a local build.
3. Compiled objects: `sudo find <sandbox> -name '*.o' | wc -l` (read-only). Quote the rate
   over 60 s or more; 2 s intervals are pure noise. Observed ~40 objects/min.
4. `make modules` is three passes: compile all `[M]` objects, then one global `modpost`,
   then link the `.ko` files. So `.ko` count stays 0 for the entire compile stage and the
   first `.ko` is the milestone that says compile is over. `modules.order` counts *modules*,
   not objects, so it cannot predict remaining object work.

Sandbox layout while a build runs: `/nix/var/nix/builds/nix-<pid>-<rand>/build/source` is the
source root, and the kbuild output directory is `.../source/build` (holds `.config` and
`include/config/auto.conf`). These are root-only (`drwx------`) and disappear when the
derivation ends; the store keeps only outputs, no build tree.

**Never run make inside a live sandbox.** GNU make executes recipes containing `$(MAKE)`
even under `-n`, so a "dry run" starts real sub-makes in a tree another build owns. Read with
`find` only.

## 4. Do not attach a progress tool to an in-flight build

- `pv` on the client log: force the width (`-w 76`) or the bar wraps in a narrower pane and
  floods the scrollback; a saturated `-s` guess shows >100% and a dead ETA. Prefer `-p -t -r`
  (no `-e`): instant ETAs collapse on quiet phases and produce hours-long nonsense.
- `nix-output-monitor`: correct for a build you start with it (`nom build …` injects
  `--log-format internal-json -v`), or `nixos-rebuild … --log-format internal-json -v 2>&1 |
  nom --json`. Its human-log mode expects nix's own log stream. Pointing it at another
  client's captured `--print-build-logs` file is unverified and is not worth the risk while a
  multi-hour derivation is in flight.
- Read-only tailing of the existing log is always safe; starting a second client is not.

## 5. Finish line

The outputs have no GC root until the switch creates the new generation (a `--no-link`
build), so do not garbage-collect between the build ending and the switch, and check the
host's GC timer before leaving. Then `nixos-rebuild switch` builds nothing and only
activates, and a kernel/U-Boot change needs a reboot.
