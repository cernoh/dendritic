---
name: dendritic-theme-scheme-wiring
description: "Work on the color scheme / theme in the dendritic flake: change or propagate the default catppuccin flavor, wire a new app's theme, or debug why an app (especially ghostty) is not showing catppuccin mocha"
---

# Dendritic theme / color-scheme wiring

Facts verified on the `cernoh/dendritic` flake (PR #83, 2026-08-28).

## Single source of truth: `modules/features/catppuccin/default.nix`

- Flake output `catppuccin`, reachable from any module as `self.catppuccin`:
  - `self.catppuccin.default` — the default flavor selector (`"mocha"`). Consumer nix files MUST read this instead of hardcoding a flavor, so repointing the default is a one-line change.
  - `self.catppuccin.mocha.<color>` — full mocha palette, hex WITHOUT `#` (ghostty/niri style), e.g. `self.catppuccin.mocha.blue == "89b4fa"`.
- Declared via `options.flake.catppuccin` (type raw) + `config.flake.catppuccin` per the dendritic-nix-flakes sharing convention.
- Already wired to it: nvf (`settings.vim.theme.style`, features/nvf), zellij (`theme = "catppuccin-${self.catppuccin.default}"`, features/programming), tmux (`@catppuccin_flavor '${self.catppuccin.default}'`, features/programming). Wire new consumers the same way.

## Consumers that CANNOT read nix values (keep in sync manually, documented in the module)

- ghostty: static file `modules/features/ghostty/config`, `theme = Catppuccin Mocha` (builtin theme name).
- noctalia: builtin `Catppuccin` + dark mode == mocha (hosts/* settings).

## Ghostty theme debugging (this was the live bug)

- Ghostty >= 1.2.3 reads `$XDG_CONFIG_HOME/ghostty/config.ghostty`; pre-1.2.3 name is `config`. BOTH load if present, `config.ghostty` FIRST (later files override earlier). Deploying `config` alone is silently ignored on modern ghostty.
- The ghostty HM module (`modules/features/ghostty/default.nix`) symlinks the repo file out-of-store:
  `xdg.configFile."config/ghostty/config.ghostty".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/ghostty/config"`.
  On the live machine the symlink target is `~/.config/dendritic/modules/features/ghostty/config`.
- NIXPC history: a stale **0-byte `~/.config/ghostty/config.ghostty`** shadowed a missing `config` symlink → ghostty ran on pure defaults. Fix = replace the empty file with the module's symlink (HM activation will not clobber an existing regular file on its own).
- Verify HEADLESS (no display needed): `ghostty +show-config` resolves the active theme + all keys (`grep -i theme`); `ghostty +list-themes` lists builtin names. Zero warnings = clean parse. Running ghostty reloads config at `ctrl+shift+,`.

## Nix eval gotchas (cost real debug cycles)

- NEW (untracked) module files are invisible to `nix eval` on a local git flake — the flake sources only git-tracked files. `git add` the new file (or commit) BEFORE eval, or you get "flake does not provide attribute".
- Verify a wired consumer: `nix eval --raw .#nixosConfigurations.NIXPC.config.home-manager.users.davr.programs.zellij.settings.theme` → `catppuccin-mocha`. tmux plugin flavor lives in the rendered conf: `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.xdg.configFile.'"tmux/tmux.conf"'.text | grep catppuccin_flavor`. ASAHI user is `da`, not `davr`.
- CI "Format Nix (changed files)" runs `nixfmt-rfc-style --check` on changed files only — but per-file, so touching a legacy-formatted file requires a FULL reflow (`nix run nixpkgs#nixfmt-rfc-style -- <files>`); nixfmt-rfc-style is now identical to pkgs.nixfmt.
