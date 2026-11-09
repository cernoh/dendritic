{ self, inputs, moduleWithSystem, ... }:
{
  flake.nixosModules.dsearch = { pkgs, ... }: {
    programs.dsearch.enable = true;
    environment.systemPackages = [ inputs.dsearch.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  };
  flake.homeManagerModules.dsearch = moduleWithSystem ({ self', ... }: { config, lib, pkgs, ... }: {
    home.packages = [ inputs.dsearch.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  });
}