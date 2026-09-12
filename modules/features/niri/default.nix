# Niri feature: scrollable-tiling Wayland compositor (ASAHI host).
#
# Package + session come from nixpkgs' programs.niri module at this lock.
# The user config is symlinked out-of-store into THIS repo checkout so it
# stays live-editable, exactly like the hm-v3 arrangement it replaces.
#
# config.kdl ends with `include "noctalia.kdl"`, which the Noctalia shell
# writes next to it at runtime — same chicken-and-egg as hm-v3, where only
# config.kdl was linked and the sibling file persisted in $HOME.
#
# The focus-ring, border, and shadow colors in config.kdl are a copy of the
# sepia palette in modules/features/scheme/default.nix. A static file cannot
# read nix values, so keep the two in sync when the palette changes.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.niri =
    {
      lib,
      ...
    }:
    {
      programs.niri.enable = true;
    };

  flake.homeManagerModules.niri =
    {
      config,
      ...
    }:
    {
      xdg.configFile.".config/niri/config.kdl".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/niri/config.kdl";
    };
}
