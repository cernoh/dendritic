# TODO: finish implementation
{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.name = moduleWithSystem ({
    pkgs,
    self',
    inputs',
    ...
  }: let
    modules = with self.nixosModules; [nvim];
  in {
    imports = modules;
    programs.name = {
      enable = true;
    };
  });
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    packages.hello = pkgs.hello;
  };
}
