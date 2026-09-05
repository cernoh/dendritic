# Ghostty terminal feature: GPU-accelerated terminal emulator.
#
# Config format per ghostty.org/docs/config: key = value lines at
# $XDG_CONFIG_HOME/ghostty/config.ghostty (the filename Ghostty >= 1.2.3
# reads; `config` is the pre-1.2.3 name — both load if present, with
# config.ghostty taking precedence). Like hm-v3, that file is symlinked
# out-of-store into THIS repo checkout so it stays live-editable
# (ctrl+shift+, reloads it at runtime).
#
# The Droid Sans Mono family in `config` resolves via `fonts.packages` in
# attrs/desktop (every desktop host imports it).
{ ... }:
{
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

      # Compositor bindings spawn "$TERMINAL" (Mango's SUPER,T). The session
      # root compositor is greeter-spawned and never sources ~/.profile, so
      # sessionVariables alone never reaches spawn_shell's non-login `sh -c`.
      # TERMINAL is registered into mango's settings.env inside the mango
      # feature module instead: nixpkgs' module system rejects any definition
      # of an option that is not declared on the host — including mkIf-false
      # ones — so a guarded def here would break every non-mango host (issue
      # #86). NIXPC pairs mango with ghostty, so the entry is unconditional.
      home.sessionVariables.TERMINAL = "ghostty";
    };
}
