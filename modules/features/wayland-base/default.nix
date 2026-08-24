# Generic Wayland desktop plumbing shared by every host (issue #25):
# Qt Wayland platforms so Qt apps render natively, the ozone flag Chromium/
# Electron builds honour, Firefox's Wayland backend, and fuzzel — which
# niri's Mod+D binding spawns and which was previously a dead keybind.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.waylandBase ];
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.waylandBase =
    {
      pkgs,
      ...
    }:
    {
      home = {
        packages = with pkgs; [
          qt5.qtwayland
          qt6.qtwayland
          fuzzel
        ];

        sessionVariables = {
          # Electron/Chromium: run natively under Wayland.
          NIXOS_OZONE_WL = "1";
          MOZ_ENABLE_WAYLAND = "1";
        };
      };
    };
}
