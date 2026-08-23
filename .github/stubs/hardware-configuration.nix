# Machine-neutral stand-in for /etc/nixos/hardware-configuration.nix, used by
# CI (and handy for local pre-push verification) so that every host preset in
# modules/hosts/ fully evaluates without a real install behind it. Copied to
# /etc/nixos/hardware-configuration.nix by .github/workflows/eval.yml; the
# voidarc guard importing it lives in modules/system/core/default.nix.
#
# Deliberately sets NO nixpkgs.hostPlatform: each host preset pins its own
# `system`, and a second definition here would collide when this x86-flavoured
# layout is imported into the aarch64 ASAHI preset.
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };
}
