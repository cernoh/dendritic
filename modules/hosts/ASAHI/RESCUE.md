# ASAHI rescue runbook — bootchain rollback and recovery

**When to use:** after an `asahi` input bump (kernel / U-Boot / m1n1) a rollback
or a boot failure leaves the machine on a bootchain that no longer matches the
switched generation. The ESP payload is only reinstalled by a `switch`, never by
`nixos-rebuild --rollback` or by booting an older generation from the
systemd-boot menu.

**Boot chain on this machine:** m1n1 stage 1 → U-Boot → stage 2 on the ESP.
The chain is managed by the asahi tooling from `modules/system/drivers/asahi.nix`
(`flake.nixosModules.asahiPlatform` → `inputs.asahi`'s
`apple-silicon-support`), not by `bootctl`: `modules/system/core/boot.nix`
pins `efi.canTouchEfiVariables = false` on aarch64 because U-Boot does not
implement EFI variable writes. The tracked `asahi` input is tpwrules/
nixos-apple-silicon main HEAD (linux-asahi 7.1.8 at the time of writing),
CI-bumped weekly — every bump lands a new kernel + bootchain that only
activates at reboot (see the `/run/reboot-required` banner from issue #72).

## 1. Boot the last known-good generation

- systemd-boot menu (hold a key / select the older entry at boot), or
- from a shell:

  ```sh
  sudo nixos-rebuild --rollback --impure --flake ~/.config/dendritic#ASAHI
  ```

  (`--rollback` switches the generation; it does **not** reinstall U-Boot/m1n1
  on the ESP — that is step 2.)

## 2. Force the bootloader payload to match the generation

Run a `switch` from the generation you want to end up on, then reboot:

```sh
sudo /run/current-system/bin/switch-to-configuration switch
sudo reboot
```

`switch-to-configuration switch` is what reinstalls U-Boot and the matching
m1n1 from that generation's store path onto the ESP. Only reboot after the
switch reports success.

## 3. If the disk system won't boot at all — USB installer

1. Boot the [Asahi Linux USB installer](https://github.com/AsahiLinux/asahi-installer)
   image. U-Boot autoboots before you can interrupt on some builds — spam any
   key at boot, then at the prompt: `bootmenu` → select `usb 0` (or
   `env set boot_efi_bootmgr ; run bootcmd_usb0`).
2. Mount the root filesystem and the ESP. The ESP path is published by the
   booted kernel, do not guess:

   ```sh
   lsblk $(cat /proc/device-tree/chosen/asahi,efi-system-partition)
   ```

   Mount root at e.g. `/mnt/root`, the ESP (vfat) at `/mnt/root/boot`.
   `/boot` must be mounted inside the chroot: `asahiConfiguration.nix`
   re-enables peripheral firmware extraction from `/boot/vendorfw` whenever a
   root rebuild evaluates that host (`hardware.asahi.peripheralFirmwareDirectory`
   in `modules/system/drivers/asahi.nix`), and a missing firmware path aborts
   firmware handling on the Mac.
3. Chroot-rebuild with the checkout (or a fresh clone of the flake):

   ```sh
   sudo mount --bind /dev /mnt/root/dev && sudo mount --bind /proc /mnt/root/proc \
     && sudo mount --bind /sys /mnt/root/sys
   sudo chroot /mnt/root /bin/bash -lc \
     'nixos-rebuild switch --impure --flake /root/dendritic#ASAHI'
   ```

   This reinstalls the ESP payload for the generation you rebuilt (step 2's
   effect, from the rescue environment).

## 4. Last resort — DFU revive

If the ESP / boot chain is unrecoverable on-device, revive via DFU from a
helper host running `services.usbmuxd.enable = true`:

```sh
# On the helper host (installs idevicerestore + starts usbmuxd)
sudo idevicerestore revive --latest
```

`revive` (as opposed to `--erase`) preserves user data. It restores a stock
bootchain; reinstall Asahi (`asahi-installer`) afterwards and re-enter this
runbook at step 3 if the NixOS system needs the ESP payload reinstalled.