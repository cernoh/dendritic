# features — opt-in feature modules

## Purpose
One directory per app/concern. Import is enabling: hosts/bundles add `self.nixosModules.<name>` or `self.homeManagerModules.<name>` to their `imports`. Each `default.nix` is a flake-parts module exporting those lower-level modules.

## Ownership
Each `features/<name>/default.nix` owns its feature. Shared patterns: out-of-store symlinks, `_*.pkg.nix` derivations, pinned flake inputs.

## Local Contracts
- **Import = enable.** No feature-defines-flag pattern. Feature is active when its module is in `imports`.
- **Module flavor by scope:**
  - System-wide (daemon, `environment.systemPackages`, NixOS option): `flake.nixosModules.<name>`.
  - Per-user (dotfiles, HM programs): `flake.homeManagerModules.<name>`.
  - Some features export both.
- **Out-of-store symlinks for live-editable config:** `fish`, `ghostty`, `niri`, `nvf`, `omp`, `opencode` link their config trees back into this checkout (e.g. `~/.config/fish` → repo path) via `mkOutOfStoreSymlink`. Edits in the repo are live without rebuild.
- **`_` data files:** `_<name>.pkg.nix` derivations, language lists, generated configs — skipped by `import-tree`, imported explicitly by `default.nix`.
- **Pinned inputs as source trees:** `dojjo` (v0.2.2, `flake=false`), `stremio-kai` (pinned rev, `flake=false`) are consumed via their `_*pkg.nix` package derivations. `davinci` input similarly.
- **Feature table (current):** `act`, `agent-browser`, `brave`, `catppuccin`, `clipboard`, `davinci`, `docker` (+ `mcp-containers.nix`), `dojjo`, `fish`, `gaming-tools`, `ghostty`, `lazygit`, `leetcode`, `mango`, `niri`, `nixpc-desktop`, `noctalia`, `noctalia-greeter`, `nushell`, `nvf`, `omp`, `opencode`, `posy-cursors`, `programming`, `steam`, `stremio-kai`, `usb-automount`, `wayland-base`, `widevine`.

## Work Guidance
- New feature: create `features/<name>/default.nix` as a flake-parts module; export the appropriate `flake.{nixos,homeManager}Modules.<name>`. Add row to `README.md` Features table.
- Prefer HM module for user config, NixOS module only when system integration is required.
- If the feature needs a derivation from a pinned input, add `_<name>.pkg.nix` beside `default.nix` and keep the input rev pinned in `flake.nix`.
- Live-editable configs: use out-of-store symlink + document it in the module header.

## Verification
- `nix-instantiate --parse modules/features/<name>/default.nix`
- `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.<user>.programs.<name> --impure` (HM features, via host eval)
- `nix flake check --impure` covers all features through host `imports`.

## Child DOX Index
- `noctalia/` — Noctalia shell feature, `cernoh/terminal` plugin, `ghostty-term` helper and its frame protocol → `modules/features/noctalia/AGENTS.md`
- `omp/` — Oh My Pi overlay, HM wrapping, managed skills, agent config, plugins → `modules/features/omp/AGENTS.md`
