# XDG desktop portals: GNOME portal for file choosers/settings, WLR portal as
# the screencast backend (OBS screen capture, browser sharing) behind mango
# and niri, GTK portal as the general fallback.
#
# Screen sharing under MangoWM needs no routing from us: the mangowm input's
# own NixOS module (nix/nixos-modules.nix, imported by features/mango) owns
# the `mango` portal section — ScreenCast/Screenshot pinned to wlr (the only
# backend speaking wlroots screencopy), Secret to gnome-keyring, everything
# else to gtk. Our job is to keep every backend that section names installed
# (a named-but-missing backend fails its interfaces), plus the common "*"
# fallback that the niri session still resolves through.
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
          # mango's portal section (owned by the mangowm input module) names
          # gtk as its default backend — without this package every
          # non-pinned interface under a MangoWM session has no backend.
          xdg-desktop-portal-gtk
        ];
        config.common.default = "*";
      };
    };
}
