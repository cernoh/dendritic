# Programming / development environment, ported from ~/.config/home-manager-v3:
#   home.nix dev packages, programs.git, programs.direnv, config/tmux.nix,
#   config/zellijConf.nix.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.programming ];
#
# Policy (issue #54): projects bring their own toolchains through direnv
#   (nix-direnv), so no global language runtime is installed here — a
#   localised bun/nodejs/jdk/... would only drift from what each project's
#   env actually pins. Editor-side LSP/formatter/DAP binaries live inside
#   the nvf feature (features/nvf), which bundles them via nvf presets.
#
# Deviations from v3, each fixing a latent break instead of copying it:
#   - gh added to packages: v3 set credential.helper = "!gh auth git-credential"
#     globally but only packaged gh on WSL, leaving other machines' helper dangling.
#   - fish added to packages: zellij.default_shell = "fish" needs a fish binary,
#     which v3 got implicitly from its shell layer that dendritic has no equivalent of yet.
#   - zellij copy_command hardcoded to wl-copy: v3 branched on a `distro`
#     specialArg (forbidden here); both dendritic hosts are Wayland.
{ self, ... }: {
  flake.homeManagerModules.programming =
    {
      pkgs,
      lib,
      ...
    }:
    let
      scheme = self.scheme;

      # Zellij themes are KDL with decimal RGB triples, and the HM module
      # writes a string value verbatim. The theme is modelled as data here so
      # the palette mapping stays readable, then rendered once.
      rgb = role: scheme.rgb.${role};
      normalEmphasis = {
        emphasis_0 = rgb "primary";
        emphasis_1 = rgb "tertiary";
        emphasis_2 = rgb "success";
        emphasis_3 = rgb "secondary";
      };
      # The four rows of the palette: normal text, selected text, and the two
      # frames. `base` is the key color, `background` the fill behind it.
      sections = {
        text_unselected = normalEmphasis // {
          base = rgb "text";
          background = rgb "mantle";
        };
        text_selected = normalEmphasis // {
          base = rgb "text";
          background = rgb "selection";
        };
        table_title = normalEmphasis // {
          base = rgb "primary";
          background = "0";
        };
        table_cell_unselected = normalEmphasis // {
          base = rgb "text";
          background = rgb "base";
        };
        table_cell_selected = normalEmphasis // {
          base = rgb "text";
          background = rgb "selection";
        };
        list_unselected = normalEmphasis // {
          base = rgb "text";
          background = rgb "base";
        };
        list_selected = normalEmphasis // {
          base = rgb "onSelection";
          background = rgb "selection";
        };
        # No per-cell background is drawn for these, so "0" means the terminal
        # default and the base color carries the emphasis.
        frame_selected = normalEmphasis // {
          base = rgb "primary";
          background = "0";
        };
        frame_highlight = {
          base = rgb "primary";
          background = "0";
          emphasis_0 = rgb "onPrimary";
          emphasis_1 = rgb "primary";
          emphasis_2 = rgb "primary";
          emphasis_3 = rgb "primary";
        };
        ribbon_unselected = {
          base = rgb "text";
          background = rgb "surfaceVariant";
          emphasis_0 = rgb "primary";
          emphasis_1 = rgb "secondary";
          emphasis_2 = rgb "tertiary";
          emphasis_3 = rgb "success";
        };
        ribbon_selected = {
          base = rgb "onPrimary";
          background = rgb "primary";
          emphasis_0 = rgb "onPrimary";
          emphasis_1 = rgb "onPrimary";
          emphasis_2 = rgb "onPrimary";
          emphasis_3 = rgb "onPrimary";
        };
        exit_code_success = {
          base = rgb "success";
          background = "0";
          emphasis_0 = rgb "info";
          emphasis_1 = rgb "base";
          emphasis_2 = rgb "secondary";
          emphasis_3 = rgb "primary";
        };
        exit_code_error = {
          base = rgb "error";
          background = "0";
          emphasis_0 = rgb "warning";
          emphasis_1 = "0";
          emphasis_2 = "0";
          emphasis_3 = "0";
        };
      };
      multiplayer = {
        player_1 = rgb "primary";
        player_2 = rgb "secondary";
        player_3 = rgb "tertiary";
        player_4 = rgb "success";
        player_5 = rgb "warning";
        player_6 = rgb "info";
        player_7 = rgb "error";
        player_8 = rgb "textMuted";
        player_9 = rgb "textDim";
        player_10 = rgb "outline";
      };
      renderBlock =
        indent: name: fields:
        lib.concatStringsSep "\n" (
          [ "${indent}${name} {" ]
          ++ lib.mapAttrsToList (field: value: "${indent}    ${field} ${value}") fields
          ++ [ "${indent}}" ]
        );
      themeFile = lib.concatStringsSep "\n" (
        [
          "themes {"
          "    ${scheme.name} {"
        ]
        ++ lib.mapAttrsToList (renderBlock "        ") sections
        ++ [
          (renderBlock "        " "multiplayer_user_colors" multiplayer)
          "    }"
          "}"
        ]
      );
    in
    {
      home.packages = with pkgs; [
        # Dev infrastructure & workflows. NOT language runtimes: direnv
        # provides those per project; NOT editor tooling: nvf bundles it.
        cachix
        devbox
        devenv
        worktrunk
        jujutsu
        gh # backs programs.git credential.helper below

        # Editor fallback & docs
        vim
        pandoc
        texliveFull
        inotify-tools

        # Shell used by zellij (see settings.default_shell)
        fish
      ];

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableFishIntegration = true;
      };

      programs.git = {
        enable = true;
        settings = {
          core.editor = "nvim";
          init.defaultBranch = "main";
          credential.helper = "!gh auth git-credential";
        };
      };

      programs.zellij = {
        enable = true;
        settings = {
          simplified_ui = true;
          # Follows the flake-wide scheme (features/scheme).
          theme = scheme.name;
          default_mode = "locked";
          default_shell = "fish";
          default_layout = "default";
          pane_frames = false;
          serialize_pane_viewport = true;
          scrollback_lines_to_serialize = 10000;
          show_startup_tips = false;
          copy_command = "wl-copy";
        };
        # Rendered to ~/.config/zellij/themes/<name>.kdl.
        themes.${scheme.name} = themeFile;
        extraConfig = ''
          keybinds clear-defaults=true {
              locked {
                  bind "Ctrl g" { SwitchToMode "normal"; }
              }
              pane {
                  bind "left" { MoveFocus "left"; }
                  bind "down" { MoveFocus "down"; }
                  bind "up" { MoveFocus "up"; }
                  bind "right" { MoveFocus "right"; }
                  bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
                  bind "d" { NewPane "down"; SwitchToMode "locked"; }
                  bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "locked"; }
                  bind "f" { ToggleFocusFullscreen; SwitchToMode "locked"; }
                  bind "h" { MoveFocus "left"; }
                  bind "i" { TogglePanePinned; SwitchToMode "locked"; }
                  bind "j" { MoveFocus "down"; }
                  bind "k" { MoveFocus "up"; }
                  bind "l" { MoveFocus "right"; }
                  bind "n" { NewPane; SwitchToMode "locked"; }
                  bind "p" { SwitchToMode "normal"; }
                  bind "r" { NewPane "right"; SwitchToMode "locked"; }
                  bind "w" { ToggleFloatingPanes; SwitchToMode "locked"; }
                  bind "x" { CloseFocus; SwitchToMode "locked"; }
                  bind "z" { TogglePaneFrames; SwitchToMode "locked"; }
                  bind "tab" { SwitchFocus; }
              }
              tab {
                  bind "left" { GoToPreviousTab; }
                  bind "down" { GoToNextTab; }
                  bind "up" { GoToPreviousTab; }
                  bind "right" { GoToNextTab; }
                  bind "1" { GoToTab 1; SwitchToMode "locked"; }
                  bind "2" { GoToTab 2; SwitchToMode "locked"; }
                  bind "3" { GoToTab 3; SwitchToMode "locked"; }
                  bind "4" { GoToTab 4; SwitchToMode "locked"; }
                  bind "5" { GoToTab 5; SwitchToMode "locked"; }
                  bind "6" { GoToTab 6; SwitchToMode "locked"; }
                  bind "7" { GoToTab 7; SwitchToMode "locked"; }
                  bind "8" { GoToTab 8; SwitchToMode "locked"; }
                  bind "9" { GoToTab 9; SwitchToMode "locked"; }
                  bind "[" { BreakPaneLeft; SwitchToMode "locked"; }
                  bind "]" { BreakPaneRight; SwitchToMode "locked"; }
                  bind "b" { BreakPane; SwitchToMode "locked"; }
                  bind "h" { GoToPreviousTab; }
                  bind "j" { GoToNextTab; }
                  bind "k" { GoToPreviousTab; }
                  bind "l" { GoToNextTab; }
                  bind "n" { NewTab; SwitchToMode "locked"; }
                  bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
                  bind "s" { ToggleActiveSyncTab; SwitchToMode "locked"; }
                  bind "t" { SwitchToMode "normal"; }
                  bind "x" { CloseTab; SwitchToMode "locked"; }
                  bind "tab" { ToggleTab; }
              }
              resize {
                  bind "left" { Resize "Increase left"; }
                  bind "down" { Resize "Increase down"; }
                  bind "up" { Resize "Increase up"; }
                  bind "right" { Resize "Increase right"; }
                  bind "+" { Resize "Increase"; }
                  bind "-" { Resize "Decrease"; }
                  bind "=" { Resize "Increase"; }
                  bind "H" { Resize "Decrease left"; }
                  bind "J" { Resize "Decrease down"; }
                  bind "K" { Resize "Decrease up"; }
                  bind "L" { Resize "Decrease right"; }
                  bind "h" { Resize "Increase left"; }
                  bind "j" { Resize "Increase down"; }
                  bind "k" { Resize "Increase up"; }
                  bind "l" { Resize "Increase right"; }
                  bind "r" { SwitchToMode "normal"; }
              }
              move {
                  bind "left" { MovePane "left"; }
                  bind "down" { MovePane "down"; }
                  bind "up" { MovePane "up"; }
                  bind "right" { MovePane "right"; }
                  bind "h" { MovePane "left"; }
                  bind "j" { MovePane "down"; }
                  bind "k" { MovePane "up"; }
                  bind "l" { MovePane "right"; }
                  bind "m" { SwitchToMode "normal"; }
                  bind "n" { MovePane; }
                  bind "p" { MovePaneBackwards; }
                  bind "tab" { MovePane; }
              }
              scroll {
                  bind "Alt left" { MoveFocusOrTab "left"; SwitchToMode "locked"; }
                  bind "Alt down" { MoveFocus "down"; SwitchToMode "locked"; }
                  bind "Alt up" { MoveFocus "up"; SwitchToMode "locked"; }
                  bind "Alt right" { MoveFocusOrTab "right"; SwitchToMode "locked"; }
                  bind "e" { EditScrollback; SwitchToMode "locked"; }
                  bind "f" { SwitchToMode "entersearch"; SearchInput 0; }
                  bind "Alt h" { MoveFocusOrTab "left"; SwitchToMode "locked"; }
                  bind "Alt j" { MoveFocus "down"; SwitchToMode "locked"; }
                  bind "Alt k" { MoveFocus "up"; SwitchToMode "locked"; }
                  bind "Alt l" { MoveFocusOrTab "right"; SwitchToMode "locked"; }
                  bind "s" { SwitchToMode "normal"; }
              }
              search {
                  bind "c" { SearchToggleOption "CaseSensitivity"; }
                  bind "n" { Search "down"; }
                  bind "o" { SearchToggleOption "WholeWord"; }
                  bind "p" { Search "up"; }
                  bind "w" { SearchToggleOption "Wrap"; }
              }
              session {
                  bind "a" {
                      LaunchOrFocusPlugin "zellij:about" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "locked"
                  }
                  bind "c" {
                      LaunchOrFocusPlugin "configuration" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "locked"
                  }
                  bind "d" { Detach; }
                  bind "o" { SwitchToMode "normal"; }
                  bind "p" {
                      LaunchOrFocusPlugin "plugin-manager" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "locked"
                  }
                  bind "w" {
                      LaunchOrFocusPlugin "session-manager" {
                          floating true
                          move_to_focused_tab true
                      }
                      SwitchToMode "locked"
                  }
              }
              shared_among "normal" "locked" {
                  bind "Alt left" { MoveFocusOrTab "left"; }
                  bind "Alt down" { MoveFocus "down"; }
                  bind "Alt up" { MoveFocus "up"; }
                  bind "Alt right" { MoveFocusOrTab "right"; }
                  bind "Alt +" { Resize "Increase"; }
                  bind "Alt -" { Resize "Decrease"; }
                  bind "Alt =" { Resize "Increase"; }
                  bind "Alt [" { PreviousSwapLayout; }
                  bind "Alt ]" { NextSwapLayout; }
                  bind "Alt f" { ToggleFloatingPanes; }
                  bind "Alt h" { MoveFocusOrTab "left"; }
                  bind "Alt i" { MoveTab "left"; }
                  bind "Alt j" { MoveFocus "down"; }
                  bind "Alt k" { MoveFocus "up"; }
                  bind "Alt l" { MoveFocusOrTab "right"; }
                  bind "Alt n" { NewPane; }
                  bind "Alt o" { MoveTab "right"; }
              }
              shared_except "locked" "renametab" "renamepane" {
                  bind "Ctrl g" { SwitchToMode "locked"; }
                  bind "Ctrl q" { Quit; }
              }
              shared_except "locked" "entersearch" {
                  bind "enter" { SwitchToMode "locked"; }
              }
              shared_except "locked" "entersearch" "renametab" "renamepane" {
                  bind "esc" { SwitchToMode "locked"; }
              }
              shared_except "locked" "entersearch" "renametab" "renamepane" "move" {
                  bind "m" { SwitchToMode "move"; }
              }
              shared_except "locked" "entersearch" "search" "renametab" "renamepane" "session" {
                  bind "o" { SwitchToMode "session"; }
              }
              shared_except "locked" "tab" "entersearch" "renametab" "renamepane" {
                  bind "t" { SwitchToMode "tab"; }
              }
              shared_except "locked" "tab" "scroll" "entersearch" "renametab" "renamepane" {
                  bind "s" { SwitchToMode "scroll"; }
              }
              shared_among "normal" "resize" "tab" "scroll" "prompt" "tmux" {
                  bind "p" { SwitchToMode "pane"; }
              }
              shared_except "locked" "resize" "pane" "tab" "entersearch" "renametab" "renamepane" {
                  bind "r" { SwitchToMode "resize"; }
              }
              shared_among "scroll" "search" {
                  bind "PageDown" { PageScrollDown; }
                  bind "PageUp" { PageScrollUp; }
                  bind "left" { PageScrollUp; }
                  bind "down" { ScrollDown; }
                  bind "up" { ScrollUp; }
                  bind "right" { PageScrollDown; }
                  bind "Ctrl b" { PageScrollUp; }
                  bind "Ctrl c" { ScrollToBottom; SwitchToMode "locked"; }
                  bind "d" { HalfPageScrollDown; }
                  bind "Ctrl f" { PageScrollDown; }
                  bind "h" { PageScrollUp; }
                  bind "j" { ScrollDown; }
                  bind "k" { ScrollUp; }
                  bind "l" { PageScrollDown; }
                  bind "u" { HalfPageScrollUp; }
              }
              entersearch {
                  bind "Ctrl c" { SwitchToMode "scroll"; }
                  bind "esc" { SwitchToMode "scroll"; }
                  bind "enter" { SwitchToMode "search"; }
              }
              renametab {
                  bind "esc" { UndoRenameTab; SwitchToMode "tab"; }
              }
              shared_among "renametab" "renamepane" {
                  bind "Ctrl c" { SwitchToMode "locked"; }
              }
              renamepane {
                  bind "esc" { UndoRenamePane; SwitchToMode "pane"; }
              }
          }

          plugins {
              about location="zellij:about"
              compact-bar location="zellij:compact-bar"
              configuration location="zellij:configuration"
              filepicker location="zellij:strider" {
                  cwd "/"
              }
              plugin-manager location="zellij:plugin-manager"
              session-manager location="zellij:session-manager"
              status-bar location="zellij:status-bar"
              strider location="zellij:strider"
              tab-bar location="zellij:tab-bar"
              welcome-screen location="zellij:session-manager" {
                  welcome_screen true
              }
          }
        '';
      };

      programs.tmux = {
        enable = true;
        shortcut = "space";
        terminal = "screen-256color";
        keyMode = "vi";
        customPaneNavigationAndResize = true;
        sensibleOnTop = true;
        mouse = true;

        plugins = with pkgs.tmuxPlugins; [
          sensible
          extrakto
          fuzzback
          lazy-restore
          mode-indicator
          ctrlw
          pain-control
          tmux-window-name
          dotbar
          vim-tmux-navigator
          yank
        ];

        extraConfig = ''
          # Sepia styles, from modules/features/scheme. The catppuccin plugin
          # is gone: it only renders catppuccin flavors, and the palette below
          # covers the status line, the borders, and the copy mode.
          set -g status-style "bg=${scheme.hex.surface},fg=${scheme.hex.textMuted}"
          set -g status-left "#[bg=${scheme.hex.primary},fg=${scheme.hex.onPrimary},bold] #S #[bg=${scheme.hex.surface},fg=${scheme.hex.primary},nobold]"
          set -g status-right "#[fg=${scheme.hex.tertiary}]#{session_name} #[fg=${scheme.hex.textDim}]#{pane_current_path} #[fg=${scheme.hex.text}]%H:%M "
          set -g window-status-format "#[fg=${scheme.hex.textDim}] #I:#W "
          set -g window-status-current-format "#[fg=${scheme.hex.onPrimary},bg=${scheme.hex.primary},bold] #I:#W "
          set -g window-status-separator ""
          set -g pane-border-style "fg=${scheme.hex.border}"
          set -g pane-active-border-style "fg=${scheme.hex.primary}"
          set -g message-style "bg=${scheme.hex.surfaceVariant},fg=${scheme.hex.text}"
          set -g message-command-style "bg=${scheme.hex.surfaceVariant},fg=${scheme.hex.primary}"
          set -g mode-style "bg=${scheme.hex.selection},fg=${scheme.hex.onSelection}"
          set -g clock-mode-colour "${scheme.hex.primary}"
          set -g copy-mode-match-style "bg=${scheme.hex.selection},fg=${scheme.hex.onSelection}"
          set -g copy-mode-current-match-style "bg=${scheme.hex.primary},fg=${scheme.hex.onPrimary}"

          # Direnv integration: clear stale DIRENV_* state at session start
          # and propagate it (plus the usual DISPLAY/SSH/etc.) to new panes so
          # the shell's direnv hook can pick up env set by neighbouring panes.
          # Replaces the default `update-environment` list with one that
          # preserves the tmux defaults and adds DIRENV_*.
          set-option -g update-environment "DISPLAY KRB5CCNAME LS_COLORS PATH SSH_ASKPASS SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION WINDOWID XAUTHORITY DIRENV_DIFF DIRENV_DIR DIRENV_WATCHES"
          set-environment -gu DIRENV_DIFF
          set-environment -gu DIRENV_DIR
          set-environment -gu DIRENV_WATCHES
          set-environment -gu DIRENV_LAYOUT

          # Enable true color support
          set -ga terminal-overrides ",*256col*:Tc"

          # Ensure status line shows everything
          set -g status-right-length 100
          set -g status-left-length 100

          # Pi-compatible key reporting: forward Shift/Ctrl/Alt+Enter distinctly
          set -g extended-keys on
          set -g extended-keys-format csi-u
        '';
      };

      # EDITOR/VISUAL are delivered system-side (attrs/programming ->
      # environment.sessionVariables) and per-shell (fish/nushell init).
      # Nothing to set here (homeless-dotfiles policy #93, issue #95).
    };
}
