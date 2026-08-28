# Ghostty terminal feature: GPU-accelerated terminal emulator.
#
# Config format per ghostty.org/docs/config: key = value lines at
# $XDG_CONFIG_HOME/ghostty/config.ghostty (the filename Ghostty >= 1.2.3
# reads; `config` is the pre-1.2.3 name — both load if present, with
# config.ghostty taking precedence). Like hm-v3, that file is symlinked
# out-of-store into THIS repo checkout so it stays live-editable
# (ctrl+shift+, reloads it at runtime).
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.ghostty =
    {
      pkgs,
      lib,
      ...
    }:
    {
      # font-family in the config resolves against this nerd-font patch of
      # Droid Sans Mono.
      fonts.packages = [ pkgs.nerd-fonts.droid-sans-mono ];
    };

  flake.homeManagerModules.ghostty =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.ghostty ];

      xdg.configFile."config/ghostty/config.ghostty".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/ghostty/config";

      # Compositor bindings spawn "$TERMINAL" (e.g. Mango's SUPER,T).
      home.sessionVariables.TERMINAL = "ghostty";
    };
}
