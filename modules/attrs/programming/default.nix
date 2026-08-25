# Programming bundle, mirroring attrs/gaming: composes existing features by
# name instead of copying them.
#   - System side: lazygit ships via environment.systemPackages.
#   - Home-manager side (editor + dev env): import self.homeManagerModules.programming;
#     system/home-manager already enables it for the primary user alongside nvf/omp.
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.programming = moduleWithSystem (
    { ... }:
    let
      modules = with self.nixosModules; [
        lazygit
      ];
    in
    {
      imports = modules;
    }
  );
}
