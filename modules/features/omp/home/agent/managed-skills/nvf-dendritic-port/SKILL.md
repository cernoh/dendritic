---
name: nvf-dendritic-port
description: "Facts needed when porting the home-manager-v3 Neovim (nvf) config into the ~/.config/dendritic master flake as a feature module; covers source-of-truth paths, flake input naming gotcha, local feature-module conventions, and the verification recipe used by merged PR #2"
---

# NVF → dendritic port facts

Status 2026-08-22: port DONE, merged via PR #2 (cernoh/dendritic, closes #1). `modules/features/nvf/` now contains `default.nix` + `_languages.nix`, `_keymaps.nix`, `_nixd.nix`. Facts below are updated with what was verified during the port.

## Source of truth

User's working nvf config lives at `~/.config/home-manager-v3/config/nvf/`:
- `nvf.nix` — main: `programs.nvf.enable` + `settings.vim = { ... }` (core/UI/theme catppuccin mocha transparent/lualine/bufferline/dashboard/lsp lspsaga trouble/conform/blink-cmp/keymaps/neo-tree/fzf-lua/gitsigns/todo-comments/nvim-dap/mini/snacks/CopilotChat lazy plugin).
- `languages.nix`, `keymaps.nix`, `nixd.nix` — plain attrsets imported via plain `import ./file.nix`.
- `nixd.nix` pins nixpkgs expr + formatting command + option exprs pointing at OLD-flake host names (`homeConfigurations.asahi` etc.) — never copy those verbatim into dendritic; drop them, keep generic nixpkgs pin + nixfmt, leave a comment showing how to re-add per-host labels once hosts exist.

## Dendritic conventions (verified)

- **import-tree skips any path containing `/_`.** Prefix plain-data sibling attrsets with `_` (e.g. `_keymaps.nix`) so they are NOT auto-imported as modules; `default.nix` imports them explicitly. Verified no stray flake outputs appear.
- Feature layout: top-level file `{inputs, ...}: { flake.<kind>Modules.<name> = {...}; perSystem = ... }`. HM consumers opt in with `imports = [ self.homeManagerModules.nvf ]`.
- Input is named **`nvf`** (`github:notashelf/nvf`). At the current lock it exposes BOTH `nvf.homeManagerModules.default` AND `inputs'.nvf.packages.default` (attr name is `default`; also `maximal`, `nix`, etc.). Never `inputs'.nvim` / `self'.package`.
- No HM/NixOS hosts exist in the dendritic flake yet, so the feature is only reachable via standalone eval or future host configs.

## Verification recipe (used successfully)

1. `nix-instantiate --parse <each file>` for fast syntax gating.
2. Whole-flake sanity: `nix eval .#packages.x86_64-linux --apply builtins.attrNames` (catches import-tree strays).
3. Standalone HM eval REQUIRES a shim module — bare `homeManagerConfiguration` fails on missing `home.stateVersion`:
   ```nix
   modules = [ flake.homeManagerModules.nvf
     { home.stateVersion = "25.05"; home.username = "test"; home.homeDirectory = "/tmp/test"; } ];
   ```
4. CopilotChat pulls UNFREE `copilot-language-server` — eval of `finalPackage` fails without `pkgs = import nixpkgs { system = ...; config.allowUnfree = true; }`.
5. Strongest no-build proof: pure-eval `config.programs.nvf.settings.mnw.initLua` to a file (~2957 lines), syntax-check with luajit from the user's existing nvim closure (`loadfile(...)`), then grep for rendered content (nixd vim.lsp.config, keymaps, theme).
6. Known env blocker (2026-08-22): building `finalPackage` fails because the dendritic lock's nixpkgs wants uncached `bash-5.3` whose stage0 bootstrap tarball hash-mismatches upstream (`cb41cbfe…tar.gz`). Proven environmental — bare `bash-5.3.drv` fails identically while `hello` builds fine and the user's working nvim closure has `bash-5.3p15` from the other flake's lock. A flake.lock bump should clear it; do not treat as a config bug.
