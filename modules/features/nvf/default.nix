# Neovim (nvf) feature, ported from ~/.config/home-manager-v3/config/nvf/.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.nvf ];
#
# Data siblings (_languages.nix, _keymaps.nix, _nixd.nix) are prefixed
# with `_` because import-tree ignores paths containing `/_`; they hold
# plain attrsets, not modules, and are imported explicitly below.
{ self, inputs, ... }:
let
  languagesConfig = import ./_languages.nix;
  keymapsConfig = import ./_keymaps.nix;
  nixdConfig = import ./_nixd.nix;
in
{
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.nvf =
    {
      pkgs,
      lib,
      ...
    }:
    {
      # Provides the programs.nvf options.
      imports = [ inputs.nvf.homeManagerModules.default ];

      programs.nvf = {
        enable = true;
        settings.vim = {
          # --- Core Editor ---
          enableLuaLoader = true;
          viAlias = true;
          vimAlias = true;

          # --- UI ---
          ui = {
            smartcolumn = {
              enable = true;
              setupOpts.colorcolumn = "80";
            };
            borders = {
              enable = true;
              plugins.lspsaga.enable = true;
            };
            noice.enable = true;
            colorizer.enable = true;
            illuminate.enable = true;
          };
          theme = {
            enable = true;
            name = "catppuccin";
            # Follows the flake-wide default scheme (features/catppuccin).
            style = self.catppuccin.default;
            transparent = true;
          };
          statusline.lualine.enable = true;
          tabline.nvimBufferline = {
            enable = true;
          };
          dashboard.dashboard-nvim = {
            enable = true;
          };

          # --- LSP ---
          lsp = {
            lspkind.enable = true;
            enable = true;
            lspsaga.enable = true;
            trouble.enable = true;
            formatOnSave = true;
            inlayHints.enable = true;
            lightbulb = {
              enable = true;
            };
            presets.nixd.enable = true;
            # nixd LSP server configuration: nixpkgs + module option
            # completion. See ./_nixd.nix.
            servers.nixd = nixdConfig;
          };
          diagnostics = {
            enable = true;
            config = {
              virtual_lines = true;
            };
            nvim-lint = {
              enable = true;
              lint_after_save = true;
            };
          };
          formatter.conform-nvim = {
            enable = true;
            setupOpts = { };
          };

          # --- Completion ---
          autocomplete = {
            blink-cmp = {
              enable = true;
              friendly-snippets.enable = true;
            };
            enableSharedCmpSources = true;
          };

          # --- Keymaps ---
          keymaps = keymapsConfig.keymaps;
          binds.whichKey.enable = true;

          # --- Navigation ---
          filetree.neo-tree.enable = true;
          fzf-lua.enable = true;
          git.gitsigns.enable = true;
          notes.todo-comments.enable = true;

          # --- Debugger ---
          debugger.nvim-dap = {
            enable = true;
            ui = {
              enable = true;
            };
          };

          # --- Mini Plugins ---
          mini = {
            animate.enable = true;
            comment.enable = true;
            pairs.enable = true;
            ai.enable = true;
            icons.enable = true;
            notify.enable = true;
          };

          # --- Utility ---
          utility = {
            snacks-nvim = {
              enable = true;
              setupOpts = { };
            };
            direnv.enable = true;
            nix-develop.enable = true;
          };

          # --- Lazy-loaded Plugins ---
          lazy.plugins = {
            "CopilotChat.nvim" = {
              package = pkgs.vimPlugins.CopilotChat-nvim;
              setupModule = "CopilotChat";
              event = [ "BufEnter" ];
              after = ''
                require('fzf-lua').register_ui_select()
              '';
            };
          };
          # --- Languages ---
          # `pkgs.flutter` (default `flutterPackage` for flutter-tools) pulls
          # `aapt` via `flutter.nix:NIX_AAPT2_BINARY_PATH`, but `aapt`
          # is only available on x86_64-linux + darwin (aapt/package.nix
          # meta.platforms). On aarch64-linux this makes the nvf module
          # un-evaluatable — `nixos-rebuild switch --flake .#ASAHI` failed
          # with: flutter-tools → flutter → aapt → "not available on aarch64-linux".
          # Gate flutter-tools there; Dart LSP/treesitter stay enabled. On
          # x86_64-linux (NIXPC) flutter-tools remains enabled.
          languages =
            languagesConfig.languages
            // lib.optionalAttrs (pkgs.stdenv.hostPlatform.isAarch64 && pkgs.stdenv.hostPlatform.isLinux) {
              dart = languagesConfig.languages.dart // {
                flutter-tools = languagesConfig.languages.dart.flutter-tools // {
                  enable = lib.mkForce false;
                };
              };
            };
        };
      };
    };

  # Raw upstream build of nvim (`.#nvf` / `nix run .#nvf`). The configured
  # editor is produced by the HM module above as programs.nvf.finalPackage;
  # this is just the input's stock package exposed per system.
  perSystem = { inputs', ... }: {
    packages.nvf = inputs'.nvf.packages.default;
  };
}
