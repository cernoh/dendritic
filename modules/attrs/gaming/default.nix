{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.gaming = moduleWithSystem (
    { ... }:
    let
      modules = with self.nixosModules; [
        steam
      ];
    in
    {
      imports = modules;

      # GameMode: lets games request the "performance" governor,
      # renice, and I/O priority while running.
      programs.gamemode.enable = true;
    }
  );
}
