# ~/.config/nushell/config.nu — LIVE-EDITABLE copy from the dendritic
# checkout (homeless-dotfiles policy #93, issue #98). Edits apply on the
# next nu start and are git-tracked.
#
# Ported verbatim from the home-manager render of the nushell feature
# module (extraConfig + shellAliases; the direnv hook below was injected by
# programs.direnv.enableNushellIntegration with the pinned direnv store
# path — bump this path when direnv updates in the flake lock).

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

$env.config = ($env.config? | default {})
$env.config.hooks = ($env.config.hooks? | default {})
$env.config.hooks.pre_prompt = (
    $env.config.hooks.pre_prompt?
    | default []
    | append {||
        let direnv = (
            /nix/store/7jf90vcsdcsn54mrydlpdhcrggrppapf-direnv-2.37.1/bin/direnv export json
            | from json --strict
            | default {}
        )

        for key in ($direnv | columns) {
            if ($direnv | get $key) == null {
                hide-env --ignore-errors $key
            }
        }

        $direnv
        | items {|key, value|
            let value = do (
                {
                  "PATH": {
                    from_string: {|s| $s | split row (char esep) | path expand --no-symlink }
                    to_string: {|v| $v | path expand --no-symlink | str join (char esep) }
                  }
                }
                | merge ($env.ENV_CONVERSIONS? | default {})
                | get ([[value, optional, insensitive]; [$key, true, true] [from_string, true, false]] | into cell-path)
                | if ($in | is-empty) { {|x| $x} } else { $in }
            ) $value
            return [ $key $value ]
        }
        | where {|pair| $pair.1 != null }
        | into record
        | load-env
    }
)

alias ".." = cd ..
alias "..." = cd ../..
alias "asahi-rebuild" = sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI
alias "cat" = bat --style=numbers,changes --color=always
alias "d" = docker
alias "dc" = docker-compose
alias "fzf" = fzf --height 40% --reverse --inline-info --preview 'bat --style=numbers,changes --color=always {}'
alias "g" = git
alias "ga" = git add
alias "gc" = git commit
alias "gp" = git push
alias "gpl" = git pull
alias "gs" = git status
alias "jc" = journalctl
alias "lg" = lazygit
alias "ll" = eza --group-directories-first --icons -la
alias "ls" = eza --group-directories-first --icons
alias "lt" = eza --group-directories-first --icons --tree
alias "nixpc-rebuild" = sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#NIXPC
alias "sc" = systemctl
