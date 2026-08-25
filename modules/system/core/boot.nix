# Boot loader defaults shared by every host.
#
# `canTouchEfiVariables = true` is right for x86 UEFI machines (NIXPC) and
# harmless on Apple Silicon: m1n1/U-Boot does not implement EFI variable
# writes, so systemd-boot's install step there is a no-op for the EFI side —
# the Mac's boot chain (m1n1 stage 1 → U-Boot → GRUB/systemd-boot stage 2 on
# the ESP) is never touched by it. ASAHI's old standalone config explicitly
# pinned false as belt-and-braces; the dendritic ASAHI host keeps that pin.
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
