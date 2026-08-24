# Gaming tools beyond Steam, ported from the gaming half of
# ~/.config/home-manager-v3/config/nixpc-config.nix home.packages
# (issue #26). One concern per feature dir: the `gaming` attr bundle
# composes this alongside steam.
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.gamingTools ];
#
# Only NIXPC (the gaming host) imports it; ASAHI does not import the
# gaming bundle at all.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.gamingTools =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        lutris
        mangohud
        gamescope
        protonup-qt
        wineWow64Packages.stable
        winetricks
        vulkan-tools
        vulkan-loader
        nvidia-vaapi-driver
      ];
    };
}
