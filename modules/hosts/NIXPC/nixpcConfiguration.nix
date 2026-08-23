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
    };
}
