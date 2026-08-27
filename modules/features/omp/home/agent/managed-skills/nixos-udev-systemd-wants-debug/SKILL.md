---
name: nixos-udev-systemd-wants-debug
description: "Debug NixOS boot-time unit failures caused by over-broad udev rules that fire via ENV{SYSTEMD_WANTS} at boot (e.g. usb-automount). Covers scoping rules, why systemd.services.name.enable=false does NOT stop a WANTS-pulled unit, and that services.udev.extraRules is types.lines."
---

# NixOS: udev rule firing at boot via SYSTEMD_WANTS

## Symptom
After `nixos-rebuild switch` + reboot, the machine "errors out" / drops failed
units, but the config evaluates fine (`nix eval ... config.system.build.toplevel`
succeeds). No eval error — the failure is at activation/boot.

## Root-cause pattern
A udev rule like:
```
ACTION=="add", SUBSYSTEM=="block", ENV{ID_FS_USAGE}=="filesystem", \
  TAG+="systemd", ENV{SYSTEMD_WANTS}="thing@%k.service"
```
matches *every* block device with a filesystem — including the root disk and
internal data disks. At boot, udev fires `thing@<root>.service` etc. before any
graphical session exists. If the helper does `exit 1` when no session is found,
the unit fails → the "errors out after reboot" symptom.

## Why the obvious disable doesn't work
- `systemd.services."thing@".enable = false;` does **NOT** stop it. `SYSTEMD_WANTS`
  on the device unit adds a `Wants=` that starts the unit regardless of
  `enable`. You must remove/condition the *rule*, not the service.
- `services.udev.extraRules = lib.mkForce "";` is wrong for surgical removal:
  `extraRules` is `types.lines`, so multiple modules' contributions are *appended*.
  `mkForce ""` adds an empty line and does not reliably delete another module's
  rule (and can interfere with unrelated rules from other modules, e.g. nvidia's
  sgx udev rules). Don't use it to subtract one rule.

## Fix
1. Scope the rule so it only matches intended devices, e.g. add
   `ENV{ID_BUS}=="usb"` (or `SUBSYSTEMS=="usb"`) so it never fires for root/data
   disks at boot.
2. Make the helper idempotent and non-fatal: check `findmnt` first (skip if
   already mounted), and `exit 0` (skip) instead of `exit 1` when no active
   graphical session exists.

## Diagnose
- View the merged rule set:
  `nix eval --system <sys> --accept-flake-config --raw .#nixosConfigurations.<H>.config.services.udev.extraRules`
- Confirm a service's enabled state:
  `nix eval --system <sys> --accept-flake-config .#nixosConfigurations.<H>.config.systemd.services."thing@".enable`
  (a boolean; `--raw` errors on bool — drop `--raw` and read the JSON `false`).
- Cross-machine eval warns about placeholder root fs ("hardwareFromMachine …
  placeholder root filesystem"); that is expected, not the bug.
