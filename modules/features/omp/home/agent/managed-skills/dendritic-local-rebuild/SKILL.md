---
name: dendritic-local-rebuild
description: "Rebuild the dendritic ASAHI (or any host) configuration on the machine itself — the only supported mode, since the NIXPC remote-builder link was retired — and verify the build plan is local"
---

# Local rebuild, no remote builder (dendritic, ASAHI/NIXPC)

## When
Any rebuild of `ASAHI`. This is no longer an opt-in: `hosts/ASAHI/default.nix` dropped the
`distributedBuilds` import and `asahiConfiguration.nix` forces `nix.buildMachines = lib.mkForce [ ]`,
so the Mac builds every derivation it installs and no `ssh-ng` builder can be scheduled.
NIXPC still imports `remoteBuilder`, but nothing is a client any more.

Two things follow that an agent must not undo:
- **`--builders ''` is no longer needed** to keep a build local. It is still harmless and is
  kept below as belt-and-braces for one invocation, but the empty `nix.buildMachines` is the
  real guarantee — it holds across any future module, overlay, or `nix.extra-platforms`.
- **`max-jobs = 4` / `cores = 0`** (`modules/hosts/ASAHI/asahiConfiguration.nix`), 8 vCPU /
  7.3 GiB RAM / ~15 GiB swap. This replaced an `mkForce 1` / `mkForce 1` ceiling that existed
  only because earlyoom kept SIGTERM'ing the biggest rustc. earlyoom is retired and forced off
  (`services.earlyoom.enable = lib.mkForce false`), with zram at 100% plus an 8 GiB `/swapfile`
  as the memory policy.

## The command (one line)
```fish
nh os boot . --impure -H ASAHI --max-jobs 4 --cores 0
```
- `-H ASAHI` selects `.#nixosConfigurations.ASAHI` explicitly (no hostname guessing).
- `--impure` is mandatory: `hardwareFromMachine` reads `/etc/nixos/hardware-configuration.nix`,
  and `asahiConfiguration.nix` reads `/boot/vendorfw` only under a root eval on this machine.
- `boot` installs the generation and sets it default without touching the running system, which
  is what you want on a compositor host: a `switch` rewrites the live `greetd` unit mid-session.
- Equivalent without nh:
  `sudo nixos-rebuild boot --impure --flake ~/.config/dendritic#ASAHI --max-jobs 4 --cores 0`
- **Wrap a long build in `systemd-inhibit`.** This box has suspended mid-session before
  (`tailscaled: time jump detected (slept 4981h15m52s)`), and a resume lands greetd on a display
  device the abandoned compositor still holds:
  ```
  sudo systemd-inhibit --what=sleep:idle --why="nixos-rebuild boot ASAHI" \
    nixos-rebuild boot --impure --flake ~/.config/dendritic#ASAHI --max-jobs 4 --cores 0
  ```

## Facts that matter
- Root is needed only for activation. `sudo -n true` fails here (no NOPASSWD, no tty
  timestamp), so an agent cannot complete the switch unattended: build as the user, then hand
  the activation command over, or run it in a terminal pane the user can type the password into.
```bash
nix build --impure --no-link --print-out-paths \
  '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
```
  The store paths persist, so the user's activation afterwards is substitution + activation.
- Verify the plan is local before committing to a long build:
```bash
nix build --dry-run --impure --no-link --print-out-paths \
  '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
```
  A `--builders ''` line never appears in `ps`, so confirm locality by the absence of any
  `ssh-ng` connection to NIXPC, not by argument text. `nix.buildMachines` being empty in the
  evaluated config is the cheap positive check:
```bash
nix eval --impure --raw '.#nixosConfigurations.ASAHI.config.nix.buildMachines'
```
- Flake eval for this repo takes minutes, long enough that the bash tool needs
  `async: true` with `timeout: 0` for the real build.
- `linux-asahi` carries `requiredSystemFeatures = [ "big-parallel" ]`. That resolves against
  the Mac's own builder through nixpkgs' default `nix.settings.system-features`
  (`benchmark big-parallel gccarch-armv8-a kvm nixos-test`). If that option is ever overridden,
  `big-parallel` must stay in it or the kernel becomes unbuildable here.
- The Asahi bootchain (`linux-asahi`, `uboot-asahi`, `m1n1`) is uncached in
  `nixos-apple-silicon.cachix.org`, so every `asahi`/`nixpkgs` bump compiles it on this Mac.
  With `cores = 0` that build now takes the whole 8-core box instead of one core. Plan the
  reboot: `/run/reboot-required` is surfaced by `asahi-reboot-notify` (issue #72), and
  `modules/hosts/ASAHI/RESCUE.md` covers rollback.