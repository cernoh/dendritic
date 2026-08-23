{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nixpcConfiguration =
    {
      lib,
      ...
    }:
    {
      networking.hostName = "NIXPC";

      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.davr.imports = [ self.homeManagerModules.mango ];
    };
}
