# Boot loader defaults shared by every host.
#
# `canTouchEfiVariables = true` is the right default for x86 UEFI machines
# (NIXPC). Apple Silicon is pinned to false: U-Boot does not implement EFI
# variable writes, so a `bootctl install` there can only fail loudly — and
# the Mac's boot chain (m1n1 stage 1 → U-Boot → stage 2 on the ESP) is
# managed by the asahi tooling, not by systemd-boot's installer. The old
# comment here claimed drivers/asahi.nix force-disabled this; it never did
# (issue #63).
{
  ...
}:
{
  flake.nixosModules.bootloader =
    {
      pkgs,
      lib,
      ...
    }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        # ESP is only 477M on ASAHI (352M already for 6 gens × ~65M Image.efi + initrds)
        # and defaults to null (keep every generation) → fills ESP after a few
        # switches and fails install with ENOSPC. Cap globally; ASAHI overrides tighter.
        systemd-boot.configurationLimit = lib.mkDefault 10;
        efi.canTouchEfiVariables = pkgs.stdenv.hostPlatform.isx86_64;
      };
    };
}
