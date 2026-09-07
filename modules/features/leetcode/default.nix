# LeetCode runner (kawre/leetcode.nvim) for the nvf editor.
#
# Opt in alongside nvf from a home-manager configuration:
#   imports = [ self.homeManagerModules.nvf self.homeManagerModules.leetcode ];
# Both hosts get it via the homeManager system module's default set.
#
# Homeless (policy #93): no `home.file` / `xdg.configFile` entries. Question
# cache, cookie, and workspace live under Neovim's runtime stdpaths
# (`~/.local/share/nvim/leetcode`, `~/.cache/nvim/leetcode` — the upstream
# `storage` defaults), owned by the plugin at runtime and never rendered by
# HM. Auth is runtime-only (`:Leet cookie update`, paste of the browser Cookie
# header); no session material ever enters the store.
#
# Contained: every Lua dependency the plugin requires travels with this
# feature — plenary + nui (required), nvim-web-devicons (optional icons), and
# the fzf-lua picker provider (pinned via `picker.provider`, ensured with
# `mkDefault` so the feature keeps working even if nvf core drops its own
# fzf-lua). Description rendering uses treesitter-html (ensured the same way).
{ ... }:
{
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.leetcode =
    {
      pkgs,
      lib,
      ...
    }:
    {
      programs.nvf.settings.vim = {
        # Picker provider for `:Leet list` / `tabs` / `lang`.
        fzf-lua.enable = lib.mkDefault true;
        # Description formatting (upstream: "optional, but highly recommended").
        languages.html.enable = lib.mkDefault true;

        lazy.plugins = {
          # --- LeetCode dependencies (plenary, nui, devicons) ---
          # Explicitly declared so leetcode.nvim never fails to resolve
          # its Lua requires at runtime. nvf's lz.n loader ensures they
          # are on runtimepath before leetcode loads.
          "plenary.nvim" = {
            package = pkgs.vimPlugins.plenary-nvim;
            lazy = false;
          };
          "nui.nvim" = {
            package = pkgs.vimPlugins.nui-nvim;
            lazy = false;
          };
          "nvim-web-devicons" = {
            package = lib.mkForce pkgs.vimPlugins.nvim-web-devicons;
            lazy = false;
          };
          # --- LeetCode runner (kawre/leetcode.nvim) ---
          # Advice from https://github.com/kawre/leetcode.nvim:
          #   * plenary + nui required, html treesitter recommended
          #   * picker auto-resolves; we pin to fzf-lua (already enabled)
          #   * non_standalone = true lets :Leet work inside any session
          "leetcode.nvim" = {
            package = pkgs.vimPlugins.leetcode-nvim;
            setupModule = "leetcode";
            setupOpts = {
              arg = "leetcode.nvim";
              lang = "python3";
              plugins = {
                non_standalone = true;
              };
              logging = true;
              cache = {
                update_interval = 60 * 60 * 24 * 7;
              };
              editor = {
                reset_previous_code = true;
                fold_imports = true;
              };
              console = {
                open_on_runcode = true;
                dir = "row";
                size = {
                  width = "90%";
                  height = "75%";
                };
                result = {
                  size = "60%";
                };
                testcase = {
                  virt_text = true;
                  size = "40%";
                };
              };
              description = {
                position = "left";
                width = "40%";
                show_stats = true;
              };
              picker = {
                provider = "fzf-lua";
              };
              hooks = { };
              keys = {
                toggle = [ "q" ];
                confirm = [ "<CR>" ];
                reset_testcases = "r";
                use_testcase = "U";
                focus_testcases = "H";
                focus_result = "L";
              };
              theme = { };
              image_support = false;
            };
            cmd = [ "Leet" ];
          };
        };

        # `<leader>l*` bindings. Merged (list-concat) with nvf core keymaps.
        keymaps = (import ./_keymaps.nix).keymaps;
      };
    };
}
