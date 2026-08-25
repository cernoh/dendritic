# XDG desktop portals, ported from the Mac's pre-dendritic configuration.nix:
# GNOME portal for file choosers/settings, WLR portal as the screencast
# backend (OBS screen capture, browser sharing) behind niri.
{
  self,
  ...
}:
{
  flake.nixosModules.portals =
    {
      pkgs,
      lib,
      ...
    }:
    {
      xdg.portal = {
        enable = lib.mkDefault true;
        xdgOpenUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal-gnome
          xdg-desktop-portal-wlr
        ];
        config.common.default = "*";
      };
    };
}
