# Neovim (nvf) feature, ported from ~/.config/home-manager-v3/config/nvf/.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.nvf ];
#
# The LeetCode runner composes from features/leetcode: this module imports
# `self.homeManagerModules.leetcode`, so enabling nvf also enables LeetCode.
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
                        config,
                        pkgs,
                        lib,
                        ...
                }:
                {
                        # Provides the programs.nvf options and composes the LeetCode runner
                        # from features/leetcode. LeetCode config targets programs.nvf, so it
                        # only makes sense inside this module, not as a standalone import.
                        imports = [
                                inputs.nvf.homeManagerModules.default
                                self.homeManagerModules.leetcode
                        ];

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
                                                # base16 takes the palette itself, so the editor follows the
                                                # flake-wide scheme (features/scheme) without a named colorscheme.
                                                name = "base16";
                                                base16-colors = self.scheme.base16;
                                                # Dead weight: nvf applies `transparent` only for a theme that
                                                # implements it (catppuccin, tokyonight, ...). The base16 setup
                                                # ignores the flag and paints `base00` on every surface. The
                                                # `luaConfigPost` entry below removes the backgrounds.
                                                transparent = true;
                                        };

                                        # Transparent editor over the ghostty background (ghostty runs at 0.85
                                        # opacity). nvf emits `luaConfigPost` after the whole `luaConfigRC` DAG,
                                        # so this entry lands after the theme and after the plugin configs:
                                        # `vim.theme.extraConfig` runs before the theme setup and would not
                                        # survive.
                                        #
                                        # One closed pass clears every background except the groups that use a
                                        # background as a signal. A per-plugin list cannot work here: trouble,
                                        # snacks, and fzf-lua define their groups only when a panel opens.
                                        luaConfigPost = ''
                                                -- Keep the backgrounds that carry a signal: selection plates,
                                                -- search hits, diff tints, and position markers. Every other
                                                -- background belongs to a surface, so it would hide the wallpaper.
                                                -- A group that keeps only a foreground needs no entry here.
                                                -- Lua patterns have no alternation, so this is a list, not one
                                                -- pattern with `|` between the parts.
                                                local signal = {
                                                  "^Visual$", "^Cursor", "^ColorColumn$", "^Folded$",
                                                  "^PmenuSel$", "^PmenuThumb$", "^TabLineSel$", "^BufferLineIndicator",
                                                  "^Search", "^Substitute$", "^MatchParen$",
                                                  "^Diff(Add|Change|Delete|Text)", "^@diff", "^@text.diff",
                                                  "^TreesitterContext", "^Illuminate", "^LspReference",
                                                  -- The lualine mode, filetype, and encoding chips show a dark
                                                  -- foreground on a cream plate. Without the plate they become
                                                  -- unreadable. The `c` section is the bar fill, so it clears.
                                                  "^lualine_[abxyz]_",
                                                }

                                                local function is_signal(name)
                                                  for _, pattern in ipairs(signal) do
                                                    if name:match(pattern) then
                                                      return true
                                                    end
                                                  end
                                                  return false
                                                end

                                                local function transparent()
                                                  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
                                                    -- A linked group follows its target, so it needs no change.
                                                    if hl.link == nil and hl.bg ~= nil and not is_signal(name) then
                                                      hl.bg = nil
                                                      -- A group the theme declares with `hl default` reads back
                                                      -- with `default = true`. Passing that flag to
                                                      -- `nvim_set_hl` makes the call a silent no-op, so the
                                                      -- background would stay.
                                                      hl.default = nil
                                                      vim.api.nvim_set_hl(0, name, hl)
                                                    end
                                                  end
                                                end

                                                transparent()
                                                -- Layers that load later, and a colorscheme change, repaint their
                                                -- own backgrounds. The pass is idempotent, so re-run it. BufEnter
                                                -- and WinEnter cover a panel that opens in its own window.
                                                vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter", "User", "BufEnter", "WinEnter", "TabEnter" }, {
                                                  callback = transparent,
                                                })
                                        '';
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
                                                # nixd LSP server configuration — nixpkgs instance,
                                                # option sets, and root markers live in ./_nixd.nix.
                                                #
                                                # The option sets come from this flake's evaluated
                                                # hosts, and the HM module cannot see the flake
                                                # attribute name of the host it runs on. Pick it by
                                                # platform — the same one-host-per-platform split the
                                                # flutter-tools gate below relies on.
                                                servers.nixd =
                                                        nixdConfig {
                                                                hostName =
                                                                        if pkgs.stdenv.hostPlatform.isAarch64 then
                                                                                "ASAHI"
                                                                        else
                                                                                "NIXPC";
                                                                userName = config.home.username;
                                                        }
                                                        // {
                                                                # nixd sends semantic tokens (attrname/select
                                                                # colouring) only with `--semantic-tokens=true`. The nvf
                                                                # preset starts a bare `nixd`, and `cmd` is a `uniq` list
                                                                # that rejects a second definition, so force the command.
                                                                # Neovim needs no enable call: 0.12 enables semantic
                                                                # tokens for every client that advertises them
                                                                # (vim/lsp/semantic_tokens.lua: `M.enable(true)`).
                                                                cmd = lib.mkForce [
                                                                        "${pkgs.nixd}/bin/nixd"
                                                                        "--semantic-tokens=true"
                                                                ];
                                                        };
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
