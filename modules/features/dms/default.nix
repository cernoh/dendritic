{ self, inputs, moduleWithSystem, ... }:
{
  flake.nixosModules.dms = { pkgs, ... }: {
    programs.dms-shell = {
      enable = true;
      systemd.enable = true;
      package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
  flake.homeManagerModules.dms = moduleWithSystem ({ self', ... }: { config, lib, pkgs, ... }: {
    programs.dms-shell = {
      enable = true;
      systemd.enable = true;
      package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  });
}