{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.wheel =
    {
      pkgs,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        pkgs.linuxPackages_latest.hid-tmff2
        self.packages.${pkgs.stdenv.hostPlatform.system}.wheel
      ];
    };
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.wheel = pkgs.oversteer;
    };
}
