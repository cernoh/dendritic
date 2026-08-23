{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.hardware =
    {
      lib,
      ...
    }:
    {
      hardware = {
        bluetooth.enable = true;
        # Wi-Fi/BT and friends; Apple Silicon peripheral firmware comes from
        # the ESP separately via drivers/asahi.nix.
        enableRedistributableFirmware = true;
      };
    };
}
