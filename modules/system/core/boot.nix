# Boot loader defaults shared by every host.
#
# Note: the Apple Silicon platform module (drivers/asahi.nix) force-disables
# `canTouchEfiVariables` because U-Boot does not support EFI variable writes;
# that override winning here is expected.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.bootloader =
    {
      lib,
      ...
    }:
    {
      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };
    };
}
