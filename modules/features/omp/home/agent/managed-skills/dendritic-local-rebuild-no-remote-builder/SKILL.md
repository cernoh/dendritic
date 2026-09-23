---
name: dendritic-local-rebuild-no-remote-builder
description: "Rebuild the dendritic ASAHI (or any host) configuration locally instead of offloading to the NIXPC remote builder, and verify the build plan is local"
---

# Local rebuild with no remote builder (dendritic, ASAHI/NIXPC)

## When
The user asks to rebuild `ASAHI` "locally", "not on the remote builder", or the NIXPC
builder is down/undesired. ASAHI imports `distributedBuilds`
(`modules/system/distributed-builds/client.nix`), which sets `nix.distributedBuilds = true`
and writes the NIXPC `ssh-ng` machine into `/etc/nix/machines`. The daemon's `builders`
default is `@/etc/nix/machines`, so every aarch64 derivation with `big-parallel` is shipped
to NIXPC.

## The command (one line)
```fish
nh os switch . --impure -H ASAHI --builders ''
```
- `--builders ''` = empty builders list; it replaces the machines-file value for that
  invocation. Honored because `da` is in `nix.settings.trusted-users`.
- `-H ASAHI` selects `.#nixosConfigurations.ASAHI` explicitly (no hostname guessing).
- `--impure` is mandatory: `hardwareFromMachine` reads `/etc/nixos/hardware-configuration.nix`.
- Equivalent without nh: `sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI --builders ''`
  (the user's fish alias `asahi-rebuild` does NOT pass `--builders ''`).

## Facts that matter
- Root is needed only for activation. `sudo -n true` fails here (no NOPASSWD, no tty
  timestamp), so an agent cannot complete the switch: build as the user, then hand the
  activation command over.
```bash
nix build --impure --builders '' --no-link --print-out-paths \
  '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
```
  The store paths persist, so the user's `nh os switch` afterwards is substitution + activation.
- Verify the plan is local before committing to a long build:
```bash
nix build --dry-run --impure --builders '' --no-link --print-out-paths \
  '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
```
  A `--builders ''` line never appears in `ps`, so confirm by the absence of any ssh-ng
  connection to 100.121.170.108, not by argument text.
- Flake eval for this repo takes ~3-4 min (measured 212 s for one dry-run), long enough that
  the bash tool background it: use `async: true` with `timeout: 0` for the real build.
- Host OOM guard: `max-jobs = 1` / `cores = 1` (`modules/hosts/ASAHI/asahiConfiguration.nix`).
  Local builds are slow on purpose; the Asahi bootchain (`linux-asahi`, `uboot-asahi`, `m1n1`)
  is uncached in `nixos-apple-silicon.cachix.org`, so a nixpkgs bump means compiling the
  kernel with one core. Do not raise the values without the user's word.
- Typical local plan after a nixpkgs bump: 11 derivations, including `linux-asahi-*` and
  `nixos-system-ASAHI-<version>`.
