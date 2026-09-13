---
name: dendritic-theme-scheme-wiring
description: "Work on the color scheme in the dendritic flake: change the sepia palette, wire a new app's theme, or debug why an app is not showing the sepia colors"
---

# Dendritic theme / color-scheme wiring

Facts verified on the `cernoh/dendritic` flake (PR #166, 2026-09-13).

## Single source of truth: `modules/features/scheme/default.nix`

- Flake output `scheme`, reachable from any module as `self.scheme`:
  - `self.scheme.name` — `"sepia"`; the theme name consumers pass to a theme selector.
  - `self.scheme.mode` — `"dark"`.
  - `self.scheme.palette.<role>` — bare hex, NO leading `#` (nvim/niri/mango style), e.g. `self.scheme.palette.primary == "c99a5b"`.
  - `self.scheme.hex.<role>` — `"#c99a5b"`, for CLI flags and CSS-shaped values.
  - `self.scheme.rgb.<role>` — `"201 154 91"`, decimal, for KDL.
  - `self.scheme.base16.<slot>` — 16 slots `base00`..`base0F`, `#rrggbb`.
  - `self.scheme.ansiNormal.<name>` / `ansiBright.<name>` — 8 each, `#rrggbb`.
  - `self.scheme.noctalia` — the Noctalia palette document, wrapped in `dark`.
  - `self.scheme.greeter` — `[appearance.palette]` for `greeter.toml`.
  - `self.scheme.omp` — the omp theme token map.
  - `self.scheme.wallpaper` — the host wallpaper path (a store path).
- Declared via `options.flake.scheme` (type raw) + `config.flake.scheme` per the dendritic-nix-flakes sharing convention.
- Every derived form comes from the single `palette` attrset, so a role change propagates everywhere.
- Wired consumers: ghostty (wrapper flags), nvf (`vim.theme.name = "base16"` + `base16-colors`), zellij (`theme` + `themes.<name>`), tmux (explicit `set -g` styles), omp (`theme.dark` + `home.activation.ompTheme`), mango (`focuscolor` and friends), noctalia (`customPalettes`), noctalia-greeter (`[appearance.palette]`), stylix (GTK and Qt).

## GTK and Qt: `modules/features/stylix`

- `inputs.stylix` follows `nixpkgs` (flake.nix) and the feature exports BOTH `flake.nixosModules.stylix` and `flake.homeManagerModules.stylix`. Both are needed: the NixOS half enables dconf and the system Qt platform theme, the HM half writes the GTK CSS, the GTK theme and the Kvantum theme.
- `stylix.autoEnable = false` keeps stylix off the applications this flake already themes itself. Only `targets.gtk.enable` and `targets.qt.enable` are set.
- `homeManagerIntegration.autoImport = false` is REQUIRED, not cosmetic. The default autoImport copies a fixed option list into each HM user, and that list contains no `targets.*.enable` entry. With autoImport left on, the HM halves of gtk and qt inherit `autoEnable = false` and stay off even though the NixOS halves are on.
- The NixOS and HM target sets are NOT the same shape: `targets.gtk.fonts` and `targets.qt.fonts` exist only on the HM side. Setting them from the NixOS module fails eval with "The option `stylix.targets.gtk.fonts' does not exist".
- The palette is passed as `base16Scheme = self.scheme.base16` (an attrset); stylix strips the leading `#`.
- Verify: `nix eval --raw --apply 'hm: hm.gtk.theme.name' .#nixosConfigurations.NIXPC.config.home-manager.users.davr` → `adw-gtk3`; `... hm.qt.kvantum.settings.General.theme` → `Base16Kvantum`. For the rendered CSS, `nix build --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.NIXPC.config.home-manager.users.davr.xdg.configFile."gtk-3.0/gtk.css".source'` — a bare `nix build <store-path>` does not work, because the path is not yet realised.
- The `targets.gtk.colors.override` route is unnecessary: the palette already arrives through `base16Scheme`.

## Consumers that CANNOT read nix values (keep in sync manually, commented in each file)

- `modules/features/niri/config.kdl` — static, symlinked out-of-store. Focus-ring, border, and shadow hex are a copy of the palette.
- `modules/features/fish/home/.config/fish/config.fish` — hydro prompt colors.
- `modules/features/nushell/home/.config/nushell/config.nu` — `color_config`.
- `modules/features/noctalia/plugins/terminal/service.luau` — the Luau sandbox has no nix access, so `blankFrame()` holds a copy.

## Noctalia palette gotcha (silent failure)

The shell reads a custom palette with the SAME parser as a community palette, and that parser returns "invalid" unless the JSON root has a `dark` object. A flat `{mPrimary, ...}` document is rejected, and the shell falls back to the builtin palette without an error. `self.scheme.noctalia` therefore returns `{ dark = { ... }; }`.

## Nix eval gotchas (cost real debug cycles)

- NEW (untracked) module files are invisible to `nix eval` on a local git flake — the flake sources only git-tracked files. Commit or `git add` the file BEFORE eval, or you get "flake does not provide attribute".
- A `jj workspace` checkout under `.worktrees/` has no git ref for its bookmark until the first push, so `nix` cannot see it. Evaluate through `git worktree add --detach <path> <commit>` instead.
- `jj` refuses to snapshot a file above 1 MiB. Raise it for the repo with `jj config set --repo snapshot.max-new-file-size <bytes>` before adding a wallpaper.
- Verify a wired consumer: `nix eval --raw .#nixosConfigurations.NIXPC.config.home-manager.users.davr.programs.zellij.settings.theme` → `sepia`. ASAHI user is `da`, not `davr`.
- Rendered artifacts: `xdg.configFile."noctalia/config.toml"`, `"noctalia/palettes/sepia.json"`, `"zellij/config.kdl"`, `"zellij/themes/sepia.kdl"`, `"tmux/tmux.conf"`.
- Validate a rendered noctalia config with the shell binary: `<noctalia>/bin/noctalia config validate <dir>`. Warnings about v4 keys are expected on the ASAHI settings.
- CI "Format Nix (changed files)" runs `nixfmt --check` on changed files only — but per-file, so touching a legacy-formatted file requires a FULL reflow.
