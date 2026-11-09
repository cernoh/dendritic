{ self, inputs, moduleWithSystem, ... }:
{
  flake.nixosModules.dcalendar = { pkgs, ... }: {
    environment.systemPackages = [ inputs.dcalendar.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
  flake.homeManagerModules.dcalendar = moduleWithSystem ({ self', ... }: { config, lib, pkgs, ... }: {
    home.packages = [ inputs.dcalendar.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  });
}