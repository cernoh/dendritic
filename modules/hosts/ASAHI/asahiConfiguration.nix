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
      hardware.asahi.peripheralFirmwareDirectory = /boot/vendorfw;
      hardware.asahi.extractPeripheralFirmware = true;

      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.davr = {
        imports = with self.homeManagerModules; [
          niri
          noctalia
          ghostty
        ];
        programs.noctalia.settings = import ./_noctalia-settings.nix;
      };
    };
}
