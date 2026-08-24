# Fish shell feature, ported from ~/.config/home-manager-v3/config/fish.nix.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.fish ];
# Fish as the primary user's LOGIN SHELL is not handled here — it lives in
# system/core (nixosModules.user), which every host gets via attrs/desktop.
#
# Deviations from v3, each fixing or adapting instead of copying:
#   - direnv hook not sourced manually: the programming feature enables
#     programs.direnv with enableFishIntegration, which appends the hook.
#   - v3 had alias text and a stray `}` pasted into interactiveShellInit;
#     dropped — those aliases already exist properly in shellAliases.
#   - PATH entry is $HOME/.local/bin only; v3 hardcoded other machines'
#     users' directories (/home/davinceyr, /home/nixos, /home/da).
#   - Rebuild helpers retargeted at this flake: nixpc-switch and the
#     nixpc-rebuild/asahi-rebuild aliases. v3 helpers pointing at outputs
#     that do not exist here (hms-flake, hmsn, hm-switch, darwin-flake)
#     were dropped rather than shipped broken.
#   - Companion binaries the config invokes are packaged here (v3 got them
#     from home.nix's system-tools block): zoxide fzf bat eza fastfetch
#     lazygit. nvim comes from the nvf feature (EDITOR/VISUAL/MANPAGER,
#     v/vim/n abbreviations). unrar is intentionally absent: the ex
#     function's .rar branch degrades to an error, as it did in v3.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.fish =
    {
      pkgs,
      ...
    }:
    {
      programs.fish = {
        enable = true;

        interactiveShellInit = ''
          # Initialize zoxide
          zoxide init fish | source

          # Set environment variables
          set -gx EDITOR nvim
          set -gx VISUAL nvim
          set -gx MANPAGER "nvim +Man!"
          set -gx PATH $HOME/.local/bin $PATH

          # Better history configuration
          set -gx HISTSIZE 10000
          set -gx HISTFILESIZE 10000

          # Hydro prompt configuration
          set -g hydro_symbol_prompt ❱
          set -g hydro_symbol_start '~'
          set -g hydro_symbol_git_dirty •
          set -g hydro_symbol_git_ahead ⇡
          set -g hydro_symbol_git_behind ⇣

          set -g hydro_color_prompt blue
          set -g hydro_color_pwd normal
          set -g hydro_color_git magenta
          set -g hydro_color_error red
          set -g hydro_color_start normal
          set -g hydro_color_duration normal

          set -g hydro_fetch true
          set -g hydro_multiline true

          set -g fish_prompt_pwd_dir_length 2
          set -g hydro_cmd_duration_threshold 1000
          set -g hydro_ignored_git_paths /tmp

          # Enable Vi mode
          fish_vi_key_bindings

          # Configure directory history navigation
          bind \e\[1\;5A history-token-search-backward
          bind \e\[1\;5B history-token-search-forward
          # zoxide + fzf: pick a directory from zoxide history
          bind -M insert \ce zoxide_fzf
          bind -M default \ce zoxide_fzf
          # fzf: pick a subcommand/flag for the current command (e.g. `omp` + Ctrl+F)
          bind -M insert \cf __fzf_search_args
          bind -M default \cf __fzf_search_args

          fastfetch
        '';

        shellAliases = {
          # Use zoxide instead of cd
          cd = "z";

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

          # System rebuilds from this flake (--impure: hardware-configuration
          # lives out-of-tree on the deploy hosts)
          nixpc-rebuild = "sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#NIXPC";
          asahi-rebuild = "sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI";
        };

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

        shellAbbrs = {
          # Git abbreviations
          g = "git";
          ga = "git add";
          gc = "git commit";
          gp = "git push";
          gpl = "git pull";
          gs = "git status";

          # Common commands
          v = "nvim";
          vim = "nvim";
          n = "nvim";

          # Docker abbreviations
          d = "docker";
          dc = "docker-compose";

          # System
          sc = "systemctl";
          jc = "journalctl";
        };

        functions = {
          mkcd = {
            description = "Create and cd into directory";
            body = "mkdir -p $argv[1] && cd $argv[1]";
          };

          fish_greeting = {
            description = "Custom fish greeting";
            body = "echo Welcome to Fish shell!";
          };

          ex = {
            description = "Extract archives";
            body = ''
              switch $argv[1]
                case '*.tar.bz2'; tar xjf $argv[1]
                case '*.tar.gz'; tar xzf $argv[1]
                case '*.bz2'; bunzip2 $argv[1]
                case '*.rar'; unrar x $argv[1]
                case '*.gz'; gunzip $argv[1]
                case '*.tar'; tar xf $argv[1]
                case '*.tbz2'; tar xjf $argv[1]
                case '*.tgz'; tar xzf $argv[1]
                case '*.zip'; unzip $argv[1]
                case '*.Z'; uncompress $argv[1]
                case '*'; echo "'$argv[1]' cannot be extracted"
              end
            '';
          };
          fh = {
            description = "Search command history";
            body = "history | fzf --reverse --height 40%";
          };

          nixpc-switch = {
            description = "Rebuild NIXPC (NixOS + embedded Home Manager) from ~/.config/dendritic";
            body = ''
              set -l repo "$HOME/.config/dendritic"
              if not test -d "$repo"
                echo "Repository not found: $repo" >&2
                return 1
              end

              pushd "$repo" >/dev/null
              or return 1

              sudo nixos-rebuild switch --impure --flake .#NIXPC
              set -l switch_status $status
              popd >/dev/null
              return $switch_status
            '';
          };

          zoxide_fzf = {
            description = "Pick a zoxide entry via fzf with a 10-box popularity rating and insert it at the cursor";
            body = ''
              # The most-frequently-used directory in the zoxide database gets 10/10
              # boxes; the rest scale proportionally. The preview pane renders the
              # selected directory's structure via `eza --tree` (falls back to `ls`).
              set -l max_score (zoxide query --list --score | awk '{print $1}' | sort -gr | head -1)
              if test -z "$max_score"
                set max_score 0
              end
              set -l entries (zoxide query --list --score | awk -v max="$max_score" '
                BEGIN { filled = "▰"; empty = "-" }
                {
                  path = $0
                  sub(/^\s*\S+\s+/, "", path)
                  rating = (max > 0) ? int($1 / max * 10 + 0.5) : 0
                  if (rating > 10) rating = 10
                  if (rating < 1 && max > 0) rating = 1
                  bar = ""
                  for (i = 0; i < rating; i++) bar = bar filled
                  for (i = rating; i < 10; i++) bar = bar empty
                  printf "%s\t%s\n", bar, path
                }
              ')
              set -l selection (printf "%s\n" $entries | fzf --height 40% --reverse --no-multi \
                --delimiter '\t' \
                --preview 'eza --tree --level=2 --color=always --group-directories-first --git-ignore {2} 2>/dev/null || ls -la {2}' \
                --preview-window=right:50%:wrap)
              if test -n "$selection"
                # Strip the 10-char bar + tab prefix to recover the bare path.
                set -l path (string sub -s 12 -- "$selection")
                commandline -i -- "$path"
              end
              commandline -f repaint
            '';
          };

          __fzf_search_args = {
            description = "Pick a subcommand/flag for the current commandline via fzf (with descriptions, pre-filled with the partial token) and insert it";
            body = ''
              set -l tokens (commandline)
              if test -z "$tokens"
                commandline -f repaint
                return
              end
              # Ensure a trailing space so complete -C treats it as "complete the next argument"
              set -l query "$tokens"
              if not string match -q -r '\s$' -- "$query"
                set query "$query "
              end
              # complete -C output is tab-separated: completion\tdescription. Preserve both columns.
              set -l candidates (complete -C -- "$query" 2>/dev/null)
              # Fall back to parsing --help for commands without fish completions
              if test -z "$candidates"
                set -l cmd (string match -rg '^\s*(\S+)' -- "$tokens")
                if command -q "$cmd"
                  # Capture flag + description when --help output uses "  --flag  description" formatting.
                  set candidates (command $cmd --help 2>&1 \
                    | string replace -ra '^\s+(-{1,2}[^\s,]+(?:,\s*-{0,2}[^\s,]+)*)\s{2,}(.*?)\s*$' '$1\t$2' \
                    | string match -r '.+\t.+')
                end
              end
              # Keep flags and subcommands; drop file/directory paths (anything with /).
              set -l filtered
              for line in $candidates
                set -l token (string match -rg '^([^\t]+)' -- "$line")
                if not string match -q -r '/' -- "$token"
                  set -a filtered "$line"
                end
              end
              set candidates $filtered
              if test -z "$candidates"
                commandline -f repaint
                return
              end
              # Pre-populate fzf's query with the partial token currently being typed.
              # Only extract when there is at least one space in the commandline AND the
              # commandline does not end with whitespace -- i.e. the user is mid-token.
              # This keeps three cases clean:
              #   "cat"     -> no pre-fill (just the command; show everything)
              #   "cat "    -> no pre-fill (cursor is past the space, about to type)
              #   "cat --h" -> pre-fill with "--h" so fzf narrows to matching flags
              set -l fzf_query ""
              if string match -q -r '\s' -- "$tokens" && not string match -q -r '\s$' -- "$tokens"
                set fzf_query (string match -rg '(\S+)\s*$' -- "$tokens")
              end
              set -l selection (printf '%s\n' $candidates | fzf --height 40% --reverse --no-multi \
                --delimiter '\t' --with-nth=1,2 --no-hscroll \
                --header 'Pick an argument' \
                --query "$fzf_query" \
                --preview 'echo {2}' --preview-window=down:1:wrap)
              if test -n "$selection"
                # Tab-separated: take the completion field, then the first alternative.
                set -l clean (string match -rg '^([^\t]+)' -- "$selection")
                set -l clean (string match -rg '^([^,\s]+)' -- "$clean")
                set -l cl (commandline)
                set -l cursor (commandline -C)
                set -l before (string sub -l $cursor -- "$cl")
                set -l token_start (string length -- (string replace -r '\S*$' "" -- "$before"))
                if test $token_start -eq 0
                  commandline -i -- " "
                  commandline -i -- "$clean"
                else
                  set -l prefix (string sub -l $token_start -- "$cl")
                  set -l suffix (string sub -s (math "$cursor + 1") -- "$cl")
                  commandline -r -- "$prefix$clean$suffix"
                  set -l clean_len (string length -- "$clean")
                  commandline -C (math "$token_start + $clean_len")
                end
              end
              commandline -f repaint
            '';
          };
        };
      };

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
