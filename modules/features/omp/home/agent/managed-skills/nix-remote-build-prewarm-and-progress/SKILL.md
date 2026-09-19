---
name: nix-remote-build-prewarm-and-progress
description: "Prewarm and watch a NixOS host's system build on a remote builder: the first-switch --builders '@/etc/nix/machines' override, the detached root client, and where build progress is (and is not) observable."
---

# Prewarm a host's system build on a remote builder

Use when a slow or OOM-capped host must build a system and a builder is available.
Pairs with `nixos-remote-builder-offload-diagnosis` (why /etc/nix/machines stays
inert) and `dendritic-asahi-cross-build` (link facts).

## Fact: the `builders` setting default makes the override one-shot

- Nix 2.34's compiled default for `builders` is `@$NIX_CONF_DIR/machines`, that is
  `@/etc/nix/machines`. Prove it on any host:
  `mkdir -p /tmp/emptyconf && touch /tmp/emptyconf/nix.conf && NIX_CONF_DIR=/tmp/emptyconf NIX_USER_CONF_FILES=/dev/null nix config show builders`
  → `@/tmp/emptyconf/machines`.
- Current nixpkgs (`nixos/modules/config/nix-remote-build.nix`) sets
  `builders = null` only when `nix.distributedBuilds = false`. An older generation
  rendered `builders = ` as an empty line, which disables the machines file.
- Therefore a host whose **running** generation shows `builders = ` empty in
  `/etc/nix/nix.conf` ignores `/etc/nix/machines`, even when the flake enables
  `nix.distributedBuilds` and the file exists. Confirm with
  `grep -E '^builders' /etc/nix/nix.conf`; a missing line means the default applies.
- One command fixes it. The first switch must carry the override; the generation it
  activates leaves `builders` unset, so later switches offload with no flag:

```sh
sudo nixos-rebuild switch --impure --flake /path/to/repo#HOST \
  --builders '@/etc/nix/machines' --option builders-use-substitutes true
```

- `--builders '@file'` is one argument and the **daemon** (root) reads the file.
  A trusted user may pass it without sudo, but root always may.
- `builders-use-substitutes true` makes the builder fetch inputs from its own
  substituters instead of receiving them from the client. It is irrelevant once
  every path is already in the client store.
- Keep `--builders` and `--option` on separate lines in any script the user pastes:
  a wrapped paste that splits `--option` from its two arguments fails with
  `argument --option: expected 2 arguments`, and a shell then reports its second
  word as an unknown command.

## Prewarm pattern (no sudo needed if the user is trusted)

Compute the derivation set as root and realize it detached, so the user's later
switch finds every path valid:

```sh
setsid env USER=root nix build --impure --keep-going \
  --builders '@/etc/nix/machines' --option builders-use-substitutes true \
  --verbose --no-link '.#nixosConfigurations.HOST.config.system.build.toplevel' \
  >> /tmp/host-remote-build.log 2>&1 < /dev/null &
```

- `USER=root` matters when the flake branches on `builtins.getEnv "USER"` (for
  example `onMacAsRoot` gates for `hardware.asahi`). Compare
  `nix eval --impure --raw '.#nixosConfigurations.HOST.config.system.build.toplevel.drvPath'`
  with and without `USER=root`. Different paths mean only the `USER=root` flavor
  is worth building, because `sudo nixos-rebuild switch` evaluates as root.
- `setsid` detaches the client from the ssh session. Nix cancels an in-progress
  build when its requesting client dies, and an interrupted build restarts from
  zero. Never kill that client.
- Do not start a second client for the same derivation set while the first waits.


## Where progress is visible, and where it is not

- Builder: no streamed log. The daemon writes `/nix/var/log/nix/drvs/<ab>/<rest>.bz2`
  only when the derivation finishes, so `nix log <drv>` on the builder prints
  nothing for an in-flight build. The live log goes to the requesting client.
- Builder, coarse signals only:
  `pgrep -fc qemu-aarch64` (count of emulated compilers; `0` means idle) and
  `uptime`. `readlink /proc/<pid>/cwd` fails: build processes belong to `nixbld*`.
- Client: its own log file. `--verbose` prints `building '…drv' on 'ssh-ng://…'`
  for remote work; a bare `building '…drv'` is a local build.
- A long tail of `Cannot build '…'` lines usually has one root cause; read the
  first failing derivation, not the cascade names.

## Cheap checks before a long run

```sh
nix build --dry-run --impure '.#nixosConfigurations.HOST.config.system.build.toplevel'
nix derivation show "$(nix eval --impure --raw '.#nixosConfigurations.HOST.config.boot.kernelPackages.kernel.drvPath')" \
  | sed -n 's/.*"requiredSystemFeatures":\(\[[^]]*\]\).*/\1/p'
```

The builder must advertise every feature the heavy derivations require. A builder
line that advertises only `big-parallel` takes a kernel whose
`requiredSystemFeatures` is `["big-parallel"]`, and silently skips any derivation
that asks for more (`gccarch-*`, `kvm`, `nixos-test`).
