---
name: dendritic-noctalia-notifications
description: "NIXPC desktop notification handling in the dendritic flake: notifications go through Noctalia's built-in daemon (org.freedesktop.Notifications), not dunst. Use when changing notification behavior on NIXPC (filters, DND, toast position, history) or editing the notification daemon wiring."
---

# Dendritic: NIXPC notifications run through Noctalia

## Fact (issue #112, PR #113, merged)

NIXPC (x86_64 desktop, compositor MangoWM + Noctalia v5 shell) handles ALL notifications via the Noctalia shell daemon. `dunst` was removed — do NOT add it back or configure it for this host; there is no dunst config anywhere in the repo.

- Noctalia claims `org.freedesktop.Notifications` (default `enableDaemon = true` in the pinned source's `NotificationConfig`; do not rely on the default alone — the settings file declares it explicitly).
- ASAHI also uses the Noctalia daemon, via the legacy settings format key `notifications.enabled = true` in `modules/hosts/ASAHI/_noctalia-settings.nix`.

## Where things live

- Daemon declaration + all per-host notification settings for NIXPC: `programs.noctalia.settings.notification` in `modules/hosts/NIXPC/nixpcConfiguration.nix`. Current content: `notification = { enable_daemon = true; }`; toast placement/filter keys are the `[notification]` / `[notification.filter.<name>]` TOML keys from https://docs.noctalia.dev/noctalia/services/notifications/ (settings attrset is serialized with nixpkgs `tomlFormat`, so `notification.filters.<name>.show_toast = false` etc. become the TOML table).
- Old-format (settingsVersion 0, ASAHI style) `notifications = { ... }` block is NOT the same shape as NIXPC's new-format `notification = { ... }`. NIXPC's compact config uses new-format keys (`shell`, `bar.main`, `plugins`, `theme`, `notification`).
- Mango autostart / helper packages (no notification daemon here anymore): `modules/features/mango/default.nix` — autostart script and `environment.systemPackages`.
- Coverage comment (dunst dropped, notifications -> noctalia): `modules/features/nixpc-desktop/default.nix`.

## Verification recipe (run on NIXPC; remote repo → issue + branch + PR)

1. `nix eval --json .#nixosConfigurations.NIXPC.config.environment.systemPackages --apply 'ps: builtins.map (p: p.name) ps'` — expect no `dunst`.
2. `nix build .#nixosConfigurations.NIXPC.config.programs.mango.package --no-link --print-out-paths` — builds the wrapper + `mango-config.conf`; `mango -c <conf> -p` validation runs at build time. Read the wrapper (`read` the generated `bin/mango`), then grep the `-c` config for `exec-once` and read the referenced autostart script from the store.
3. `nix build .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.activationPackage --no-link --print-out-paths` — generated TOML at `<out>/home-files/.config/noctalia/config.toml` (symlink into a `noctalia-config` store path; `read` it with `:raw`).
4. Full closure check: build `.#nixosConfigurations.NIXPC.config.system.build.toplevel --no-link`, then `nix path-info -r <out>` and count `dunst` matches (expect 0).
5. Do not activate unless the user asks; building is proof enough for a config change.

## Traps

- Settings attrset keys serialize 1:1 to TOML sections — a Nix value change on the wrong key silently no-ops or adds an unused section. Verify the generated TOML (step 3) after every settings change.
- Two daemons for the same D-Bus name race at session start; whoever starts first wins. When moving notification duty between daemons, remove the loser from autostart AND systemPackages, then verify the closure.
