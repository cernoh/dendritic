# Flatpak support, ported from the Mac's pre-dendritic configuration.nix.
# Flathub remote must be added manually once per machine:
#   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
{
  self,
  ...
}:
{
  flake.nixosModules.flatpak =
    {
      lib,
      ...
    }:
    {
      services.flatpak.enable = lib.mkDefault true;
    };
}
