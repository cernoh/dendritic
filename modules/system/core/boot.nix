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
      ...
    }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = pkgs.stdenv.hostPlatform.isx86_64;
      };
    };
}
