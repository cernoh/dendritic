# Shared desktop-machine base: core system + networking + audio + removable
# media handling + home-manager features.
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.desktop = moduleWithSystem (
    { ... }:
    let
      modules = with self.nixosModules; [
        core
        network
        audio
        usbAutomount
        homeManager
      ];
    in
    {
      imports = modules;
    }
  );
}
