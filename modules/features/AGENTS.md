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
- **User-scoped services carry an explicit PATH.** `systemd.user.services.<name>` starts with systemd's compiled-in search path, which excludes `/run/current-system/sw/bin`. List every binary the service runs in `Service.Environment.PATH` (`lib.makeBinPath`); `herdr-web` needs `herdr`, `zoxide`, `find`, and `ss`.
- **A loopback service reaches the tailnet through an opt-in option.** `herdr-web` declares `services.herdr-web.tailscaleServe` on its NixOS module and reads the port and bind address back from the home-manager service, so a change cannot make the proxy and the listener disagree. The unit is a oneshot: `tailscale serve --bg` writes the mapping, and `ExecStop` removes that port with `tailscale serve --https=<port> off`.
- **A feature on both hosts takes its machine facts as options.** Import stays the enable switch; what differs per machine arrives through a `dendritic.<feature>` option set that the host assigns from its `hosts/<HOST>/_<feature>-settings.nix`. `mango` (issue #245) declares `dendritic.mango.{monitorRule,extraEnv,extraBinds,gaps,borderWidth}`; a module that declares `options` MUST put its configuration under an explicit `config` attribute (`imports` stays a module key at the top level).
- **`_` data files:** `_<name>.pkg.nix` derivations, language lists, generated configs — skipped by `import-tree`, imported explicitly by `default.nix`.
- **Docker Compose stacks pair a `compose.yaml` with its `compose2nix` output.** The compose file is the source of truth, the generated module sits beside it behind the `_` prefix, and the feature's `default.nix` adds what compose2nix cannot express (child image, secret files, mount ordering, tailnet publish). `paseo` is the reference example.
- **Pinned inputs as source trees:** `dojjo` (v0.2.2, `flake=false`), `stremio-kai` (pinned rev, `flake=false`) are consumed via their `_*pkg.nix` package derivations. `davinci` input similarly. `retrosmart-cursor` (tag v2.0.1, `flake=false`) is the same: its XPM artwork and build scripts feed `features/retrosmart-cursor/_retrosmart-cursor.pkg.nix`.
- **Feature table (current):** `act`, `agent-browser`, `brave`, `clipboard`, `computer-use`, `davinci`, `docker` (+ `mcp-containers.nix`), `dojjo`, `fish`, `gaming-tools`, `ghostty`, `herdr-web`, `lazygit`, `leetcode`, `mango`, `nautilus`, `niri`, `nixpc-desktop`, `noctalia`, `noctalia-greeter`, `nushell`, `nvf`, `omp`, `opencode`, `paseo`, `posy-cursors`, `programming`, `retrosmart-cursor`, `scheme`, `steam`, `stremio-kai`, `stylix`, `usb-automount`, `wayland-base`, `widevine`.
- **The pointer cursor has two delivery channels.** `home.pointerCursor` (set by `features/retrosmart-cursor`) covers the home profile, `~/.icons`, the GTK cursor theme, and login shells. A greeter-spawned compositor takes its environment from its own config instead, so `mango`'s `settings.env` and niri's `config.kdl` `environment` block both carry `XCURSOR_THEME`, read from `self.retrosmartCursor`.
- **`scheme` owns every color.** It exports `flake.scheme` (roles, base16, ANSI, noctalia/greeter/omp/html documents, wallpaper). A themed feature MUST read `self.scheme` instead of a local hex. Features that cannot read nix values keep a copy and name the file to sync.
- **nixd completes options from the evaluated hosts.** `features/nvf/_nixd.nix` builds nixd's `options` providers from `nixosConfigurations.<HOST>.options` (HOST picked by platform, since the HM module cannot see the flake attribute name) and from the home-manager tree that `system/home-manager` exports; flake-parts paths come from `debug.options`/`currentSystem.options` (`parts.nix` sets `debug = true`). Flake *inputs* are not completable: nixd recognises only the `pkgs` and `lib` select idioms.
- **`stylix` themes GTK and Qt from `self.scheme.base16`.** It exports both a `nixosModules` and a `homeManagerModules` output, because dconf and the system Qt platform theme are NixOS-side while the GTK CSS and Kvantum theme are HM-side. `autoEnable = false` and `homeManagerIntegration.autoImport = false` keep it off every application this flake themes itself; each new target is added explicitly.

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
- `noctalia/` — Noctalia shell feature, `cernoh/terminal` and `cernoh/mirai` plugins, `ghostty-term` helper and its frame protocol, `mirai` Miracast CLI → `modules/features/noctalia/AGENTS.md`
- `omp/` — Oh My Pi overlay, HM wrapping, managed skills, agent definitions, agent config, plugins → `modules/features/omp/AGENTS.md`
