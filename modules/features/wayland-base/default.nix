# Generic Wayland desktop plumbing shared by every host (issue #25):
# Qt Wayland platforms so Qt apps render natively, the ozone flag Chromium/
# Electron builds honour, Firefox's Wayland backend, and fuzzel — which
# niri's Mod+D binding spawns and which was previously a dead keybind.
#
# Split delivery (homeless-dotfiles policy #93):
#   - NixOS side: NIXOS_OZONE_WL and MOZ_ENABLE_WAYLAND reach login shells,
#     systemd user units and the session-root compositor via
#     `environment.sessionVariables` (issue #95).
#     The greeter-spawned niri on ASAHI inherits these (verified via
#     /proc/<niri-pid>/environ), and the mango compositor on NIXPC re-exports
#     them to its spawn_shell children from the mango feature's settings.env.
#   - HM side: the packages only.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.waylandBase ];
# and from a host (both hosts do, via attrs/desktop):
#   imports = [ self.nixosModules.waylandBase ];
{ ... }: {
  # NixOS side: system env for every desktop host.
  flake.nixosModules.waylandBase =
    { ... }:
    {
      environment.sessionVariables = {
        # Electron/Chromium: run natively under Wayland.
        NIXOS_OZONE_WL = "1";
        MOZ_ENABLE_WAYLAND = "1";
      };
    };

  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.waylandBase =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        qt5.qtwayland
        qt6.qtwayland
        fuzzel
      ];
    };
}
