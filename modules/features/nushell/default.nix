# Nushell as the secondary interactive shell, ported from
# ~/.config/home-manager-v3/config/nushell.nix. Fish remains the login shell
# (system/core/user); this module only needs importing into the HM user.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.nushell ];
#
# Deviations from v3, each deliberate:
#   - Rebuild helpers retargeted at this flake: nixpc-rebuild / asahi-rebuild,
#     mirroring the fish feature. v3's hms-flake, hmsn, nrs, darwin-flake and
#     the hm-switch function pointed at home-manager-v3#fedora|#debian|#nixwsl
#     |darwin outputs that do not exist here — dropped rather than shipped
#     broken.
#   - PATH entry is $HOME/.local/bin only; v3 hardcoded other machines'
#     users' directories (/home/davinceyr, /home/nixos, /home/da).
#   - zoxide integration comes from programs.zoxide.enableNushellIntegration.
#     v3's `zoxide init nushell | save -f ~/.zoxide.nu` inside extraEnv raced
#     HM-managed files, and extraConfig sourced that generated file — both
#     gone. The companion binary ships via the same module.
#   - history.sync_on_enter dropped: removed upstream in current Nushell;
#     max_size and the color_config block are kept verbatim.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.nushell =
    {
      pkgs,
      ...
    }:
    {
      programs = {
        nushell = {
          enable = true;

          shellAliases = {
            # Use bat instead of cat with syntax highlighting
            cat = "bat --style=numbers,changes --color=always";

            # Use eza instead of ls with icons and directories first
            ls = "eza --group-directories-first --icons";
            ll = "eza --group-directories-first --icons -la";
            lt = "eza --group-directories-first --icons --tree";

            ".." = "cd ..";
            "..." = "cd ../..";

            # Use fzf for fuzzy finding
            fzf = "fzf --height 40% --reverse --inline-info --preview 'bat --style=numbers,changes --color=always {}'";

            # Use lazygit for git operations
            lg = "lazygit";

            # Git abbreviations
            g = "git";
            ga = "git add";
            gc = "git commit";
            gp = "git push";
            gpl = "git pull";
            gs = "git status";

            # Docker abbreviations
            d = "docker";
            dc = "docker-compose";

            # System rebuilds from this flake (--impure: hardware-configuration
            # lives out-of-tree on the deploy hosts)
            nixpc-rebuild = "sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#NIXPC";
            asahi-rebuild = "sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI";

            # System
            sc = "systemctl";
            jc = "journalctl";
          };

          extraConfig = ''
            # Source custom functions (mkcd, ex, fh)
            source ~/.config/nushell/functions.nu

            # Better history settings
            $env.config.history.max_size = 10000

            # Colors
            $env.config.color_config = {
              separator: "white"
              leading_trailing_space_bg: { attr: n }
              header: "green"
              empty: "blue"
              bool: {|| if $in { "light_cyan" } else { "light_red" }}
              int: "white"
              filesize: {|e|
                if $e == 0b {
                  "white"
                } else if $e < 1mb {
                  "cyan"
                } else {
                  "blue"
                }
              }
              duration: "white"
              date: {|| (date now) - $in |
                if $in < 1hr {
                  "red"
                } else if $in < 6hr {
                  "orange"
                } else if $in < 1day {
                  "yellow"
                } else if $in < 3day {
                  "green"
                } else {
                  "cyan"
                }
              }
              record: "white"
              list: "white"
              block: "white"
              hints: "dark_gray"
              search_result: {fg: "white" bg: "red"}
            }
          '';

          extraEnv = ''
            # Editor variables; nvim itself comes from the nvf feature
            $env.EDITOR = "nvim"
            $env.VISUAL = "nvim"
            $env.MANPAGER = "nvim +Man!"

            # User-local binaries only — no cross-machine hardcodes
            $env.PATH = ($env.PATH | split row (char esep) | prepend [$"($env.HOME)/.local/bin"] | uniq)
          '';
        };

        zoxide.enableNushellIntegration = true;
      };

      # Companion binaries the config invokes through aliases/functions.
      xdg.configFile."nushell/functions.nu".text = builtins.readFile ./_functions.nu;

      home.packages = with pkgs; [
        bat
        eza
        fzf
        lazygit
      ];
    };
}
