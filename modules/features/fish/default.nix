# Fish shell feature, ported from ~/.config/home-manager-v3/config/fish.nix.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.fish ];
# Fish as the primary user's LOGIN SHELL is not handled here — it lives in
# system/core (nixosModules.user), which every host gets via attrs/desktop.
#
# Homeless config (issue #98, policy #93): the interactive config is
# live-editable and lives in the checkout — config.fish and the custom
# functions are symlinked into ~/.config/fish via mkOutOfStoreSymlink
# (the established ghostty/niri/opencode pattern), so edits are git-tracked
# and roll back with the repo. Ported verbatim from the home-manager render
# of this module's former interactiveShellInit/shellAliases/shellAbbrs/
# functions options.
#
# What the module still delivers (store content is unavoidable here):
#   - fish plugins (nix-env, fzf.fish, hydro, done, autopair) — their
#     conf.d loaders embed plugin store paths
#   - the session-vars loader (conf.d/00-hm-session-vars.fish): the
#     sessionVariablesPackage store path must be regenerated every switch,
#     so it stays module-generated; fish sources conf.d before config.fish
#   - completions integration (generated_completions dir)
#
# Deviations from v3, each fixing or adapting instead of copying:
#   - direnv hook not sourced manually: the programming feature enables
#     programs.direnv with enableFishIntegration, which appends the hook.
#   - PATH entry is $HOME/.local/bin only; v3 hardcoded other machines'
#     users' directories.
#   - Rebuild helpers retargeted at this flake (see config.fish/functions).
#   - Companion binaries the config invokes are packaged here: zoxide fzf
#     bat eza fastfetch lazygit. nvim comes from the nvf feature.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.fish =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      programs.fish = {
        enable = true;

        plugins = [
          {
            name = "nix-env";
            src = pkgs.fetchFromGitHub {
              owner = "lilyball";
              repo = "nix-env.fish";
              rev = "7b65bd228429e852c8fdfa07601159130a818cfa";
              sha256 = "RG/0rfhgq6aEKNZ0XwIqOaZ6K5S4+/Y5EEMnIdtfPhk=";
            };
          }
          {
            name = "fzf.fish";
            src = pkgs.fishPlugins.fzf-fish.src;
          }
          {
            name = "hydro";
            src = pkgs.fishPlugins.hydro.src;
          }
          {
            name = "done";
            src = pkgs.fishPlugins.done.src;
          }
          {
            name = "autopair";
            src = pkgs.fishPlugins.autopair.src;
          }
        ];
      };

      # config.fish: checkout symlink, overriding the HM-generated render.
      # mkForce because the fish module defines the same option (source
      # auto-derives from its text at mkDefault priority).
      xdg.configFile."fish/config.fish".source = lib.mkForce (
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/fish/home/.config/fish/config.fish"
      );

      # Session vars (TERMINAL etc.) that the rendered config.fish used to
      # source from the store. Module-generated so the content-addressed
      # store path always matches the current generation; fish loads
      # conf.d/*.fish before config.fish.
      xdg.configFile."fish/conf.d/00-hm-session-vars.fish".source =
        "${config.programs.fish.sessionVariablesPackage}/etc/profile.d/hm-session-vars.fish";

      # Custom functions autoload from the checkout symlink (fish loads
      # ~/.config/fish/functions/*.fish on demand).
      home.file.".config/fish/functions".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/fish/home/.config/fish/functions";

      # Binaries the fish config invokes at startup or through its aliases,
      # keybindings and functions (see header note for what comes from where).
      home.packages = with pkgs; [
        fastfetch
        eza
        bat
        fzf
        zoxide
        lazygit
      ];
    };
}
