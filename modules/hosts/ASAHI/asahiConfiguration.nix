{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.asahiConfiguration =
    {
      lib,
      ...
    }:
    {
      networking.hostName = "ASAHI";

      # Peripheral firmware (Wi-Fi, webcam, ambient light sensor) from the
      # dump the Asahi installer places on the ESP. Only evaluable/buildable
      # ON this machine: /boot/vendorfw is root-only, so foreign machines
      # fail while stat-ing the path. Rebuild with:
      #   sudo nixos-rebuild switch --impure --flake .#ASAHI
      hardware.asahi.peripheralFirmwareDirectory = /boot/vendorfw;
      hardware.asahi.extractPeripheralFirmware = true;
    };
}
