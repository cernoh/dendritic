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
    };
}
