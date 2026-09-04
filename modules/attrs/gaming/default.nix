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
        sober
      ];
    in
    {
      imports = modules;
    }
  );
}
