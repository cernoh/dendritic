# Nushell as the secondary interactive shell, ported from
# ~/.config/home-manager-v3/config/nushell.nix. Fish remains the login shell
# (system/core/user); this module only needs importing into the HM user.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.nushell ];
#
# Homeless config (issue #98, policy #93): config.nu, env.nu and functions.nu
# are live-editable checkout symlinks (mkOutOfStoreSymlink, ghostty/niri
# pattern). Ported verbatim from the module's former extraConfig/extraEnv
# renders plus the tracked _functions.nu — which was already a store copy of
# a git-tracked file and is now symlinked directly.
#
# Deviations from v3:
#   - Rebuild helpers live in the checkout files (asahi-rebuild/nixpc-rebuild
#     aliases), retargeted at this flake.
#   - zoxide output comes through fish (/programs.zoxide integration is inert
#     here since the render is repo-owned; add `zoxide init nushell` to
#     config.nu manually if wanted).
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.nushell =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      programs.nushell.enable = true;

      # Checkout symlinks, mkForce over the HM-rendered text (the file-type
      # source is mkDefault-derived from text, so a forced def wins).
      home.file."${config.xdg.configHome}/nushell/config.nu".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/nushell/home/.config/nushell/config.nu"
      );
      home.file."${config.xdg.configHome}/nushell/env.nu".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/nushell/home/.config/nushell/env.nu"
      );
      xdg.configFile."nushell/functions.nu".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/nushell/home/.config/nushell/functions.nu";

      # Companion binaries the config invokes through aliases/functions.
      home.packages = with pkgs; [
        bat
        eza
        fzf
        lazygit
      ];
    };
}
