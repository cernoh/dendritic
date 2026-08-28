# Apple Silicon platform support via tpwrules/nixos-apple-silicon:
# Asahi kernel + m1n1/U-Boot boot chain, SMC/NVMe initrd modules, schedutil,
# peripheral firmware extraction from the ESP.
#
# No GPU toggles needed at the locked input revision: Asahi support lives in
# mainline mesa now (useExperimentalGPUDriver/withRust were removed upstream).
#
# NOTE: upstream's peripheral-firmware machinery probes /boot/vendorfw with
# plain pathExists and pulls the path into derivation inputs — both throw on
# machines where /boot is absent or root-only, so ANY evaluation referencing
# the firmware breaks cross-machine `nix flake check`. Defaults here keep
# extraction off; hosts/ASAHI re-enables it with the real ESP path, which is
# only evaluable/buildable on the Mac itself (root rebuild).
#
# No GPU toggles needed at the locked input revision: Asahi support lives in
# mainline mesa now (useExperimentalGPUDriver/withRust were removed upstream).
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.asahiPlatform =
    {
      lib,
      ...
    }:
    {
      imports = [ inputs.asahi.nixosModules.apple-silicon-support ];

      hardware.asahi.enable = true;

      # Neutralise upstream's throwing auto-detection defaults (see NOTE).
      hardware.asahi.peripheralFirmwareDirectory = lib.mkDefault null;
      hardware.asahi.extractPeripheralFirmware = lib.mkDefault false;

      # Reboot-required signalling (issue #72). An asahi input bump ships a
      # new kernel/U-Boot/m1n1, but `switch` keeps them inert until reboot, so
      # switched-but-unbooted generations can silently accumulate. Compare the
      # booted vs current kernel at every activation (after the /etc
      # regeneration so the banner survives etc-cleanup):
      #   - switch: /run/current-system already points at the new generation
      #     while /run/booted-system still points at the old one → flag set
      #   - boot:   activation runs with booted == current            → cleared
      # Consumers: the /run/reboot-required flag file, a TTY banner under
      # /etc/issue.d (agetty ≥ 2.38), and the asahi-reboot-notify desktop
      # notification declared in hosts/ASAHI/asahiConfiguration.nix.
      system.activationScripts.asahiRebootRequired = {
        deps = [ "etc" ];
        text = ''
                    booted="$(readlink -f /run/booted-system/kernel 2>/dev/null || true)"
                    current="$(readlink -f /run/current-system/kernel 2>/dev/null || true)"
                    if [ -n "$current" ] && [ "$booted" != "$current" ]; then
                      mkdir -p /etc/issue.d
                      cat > /etc/issue.d/50-reboot-required.issue <<'ISSUE'
          *** REBOOT REQUIRED ***
          The switched generation loads a different kernel than the booted one (asahi
          input bumps: kernel/U-Boot/m1n1 only activate at reboot). Reboot to load it;
          see modules/hosts/ASAHI/RESCUE.md if a rollback is needed first.
          ISSUE
                      touch /run/reboot-required
                    else
                      rm -f /run/reboot-required /etc/issue.d/50-reboot-required.issue
                    fi
        '';
      };
    };
}
