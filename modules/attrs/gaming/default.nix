{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.gaming = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [
      steam
    ];
  in {
    imports = modules;
  });
}
