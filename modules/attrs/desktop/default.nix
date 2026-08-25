# Shared desktop-machine base: core system + networking + audio + removable
# media handling + home-manager features + act (local GitHub Actions runner,
# pulls in the docker runtime).
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
        act
      ];
    in
    {
      imports = modules;
    }
  );
}
