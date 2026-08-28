---
name: dendritic-homeless-dotfiles
description: "Design dendritic flakes with homeless dotfiles: deliver app config via CLI flags, env vars, wrapper scripts, or system-level NixOS options instead of home-manager user profiles. Use when adding a new app/config to the dendritic flake, deciding where a config file should live, reviewing a feature for home-manager overuse, or porting config from a legacy hm setup."
---

# Dendritic homeless dotfiles

## Principle

Config belongs to the flake, not to a user's home. In this repo — and
dendritic-pattern flakes generally — deliver application configuration through
mechanisms that keep the source of truth in the store or the repo checkout
(command-line flags, environment variables, wrapper scripts, system-level NixOS
options) and treat home-manager user profiles as the **last resort**.

"Homeless" means: no `~/.config/<app>` file owned by a home-manager user
profile. The flake owns the config; the app reads it from wherever the flake
put it (store path, `/etc`, repo checkout, or an env/flag the flake sets).

## Why (lessons already paid for in this repo)

- **HM state is per-user and ages independently.** `backupFileExtension =
  "hm-backup"` renames pre-existing dotfiles on first switch (#64); stale
  hm-v3 generations linger until `home-manager expire-generations`; a
  mismatched `dendritic.userName` creates a second account (#62).
- **HM activation is a separate service** (`home-manager-da.service`). A
  system switch does not activate HM config and vice versa — two clocks to
  reconcile. A homeless config moves atomically with the generation.
- **Profiles don't reach the processes that need env.** `home.sessionVariables`
  → `~/.profile` never reaches the greeter-spawned compositor or its
  `spawn_shell` children; `TERMINAL` had to be pushed through the compositor's
  own settings.env instead (mango feature, issue #86).
- **Homeless config is trivially cross-host.** A system option or store path
  behaves identically on NIXPC and ASAHI; HM config is keyed to a user name
  and duplicated per host block.
- **Rollback is honest.** `nixos-rebuild --rollback` moves system-delivered
  config with the generation; rolled-back HM config needs a separate HM
  rollback.

## Delivery ladder (prefer the top rung)

1. **System-level options** — `programs.<app>.*`, `environment.etc.<path>.source`,
   `services.*`: config evaluated into the store, activated with every switch,
   identical on every host.
2. **CLI flags** — the app accepts a config path (`--config`, `-c`, `-f`, `-u`);
   pass a store path or repo path baked into the invocation. Confirm the flag
   exists with `app --help`; never assume one.
3. **Environment variables** — per-app config/state vars (`XDG_CONFIG_HOME`
   scoped to a wrapper, `NVIM_APPNAME`, `MPV_HOME`, `GIT_CONFIG_GLOBAL`, ...).
   Use `environment.sessionVariables` only when the consumer actually reads the
   profile (see the compositor lesson above).
4. **Wrapper scripts / packaged flags** — `pkgs.writeShellScriptBin` + `exec`,
   or `wrapProgram`, baking the flag/env into a PATH-visible binary.
5. **Out-of-store symlink** — the established repo pattern
   (`config.lib.file.mkOutOfStoreSymlink`) for configs that MUST stay
   live-editable: a thin symlink into the repo checkout, never a content copy.
   See the hm-out-of-store-symlinks skill.
6. **Home-manager content config** — last resort, reserved for
   home-session-bound apps with no flag/env escape hatch (e.g.
   `programs.noctalia.settings` renders a full TOML).

## Concrete mechanisms

- **System options:** `programs.git.config` (NixOS), `environment.etc."foo.conf".source
  = ./foo.conf;`, `systemd.services.<x>.environment`. The config is a store
  file; apps that honor `/etc/<app>.<ext>` or `XDG_*` pick it up for free.
- **Flags:** `nvim -u <path>`, `git -c key=val` / `GIT_CONFIG_GLOBAL`, `tmux -f`,
  `fish -C`, `mpv --config-dir`, terminal emulators with `--config-file`-style
  flags. Bake the store path into a wrapper rather than hardcoding a home path.
- **Env:** per-app `*_HOME`/`*_CONFIG` vars; `XDG_CONFIG_HOME` redirected for a
  single wrapper (`XDG_CONFIG_HOME=${cfgDir} exec app`) so the rest of the
  user's tree is untouched.
- **Wrapper example (flake-parts):**
  ```nix
  perSystem = { pkgs, ... }: {
    packages.foo-wrapped = pkgs.writeShellScriptBin "foo" ''
      exec ${pkgs.foo}/bin/foo --config ${./foo.conf}
    '';
  };
  ```
  Add the wrapped binary to `environment.systemPackages` — no dotfiles at all.
- **Compositor env pattern (mango):** register env in the session root's own
  settings list (`wayland.windowManager.mango.settings.env`), the only channel
  compositor-spawned shells see; never rely on the profile for these.

## When home-manager is still right

Explicit exceptions — keep them thin:

- Apps that are **inherently session-bound and live-editable** (ghostty, niri,
  fish, omp, opencode in this repo): out-of-store symlink into the checkout,
  never content copies, so edits stay in git and roll back with the repo.
- HM features that are themselves the integration point (e.g.
  `programs.noctalia.settings`).

Rule of thumb: config the user edits live → symlink into the checkout; static
deploy-time config → store/flag/env; only if neither is possible → HM content,
and flag it in review.

## Verification: prove a config is homeless

1. No `home.file` / `xdg.configFile` / `home-manager.users` entries for the app
   in its feature module:
   ```bash
   grep -n "home.file\|xdg.configFile\|home-manager.users" modules/features/<app>/default.nix
   ```
2. The app's effective config path resolves into the store or repo:
   - flag/env path: `nix eval --raw '.#nixosConfigurations.<HOST>.config...'` or
     read the wrapper's `exec` line → expect `/nix/store/...` or a
     `~/.config/dendritic/...` checkout path.
3. No `*.hm-backup` files appear on first switch and
   `home-manager expire-generations` is a no-op for that app (#64).

## Review checklist for a new or ported app

- [ ] Can the app take its config from a flag/env/path? → use it; do not write
      `~/.config/<app>` via HM
- [ ] Is the config static? → store-side (system option / `environment.etc`) over
      repo symlink
- [ ] Will the user edit it live? → out-of-store symlink into the checkout,
      content stays in git
- [ ] Per-user differences actually needed? → only THEN consider HM, and keep
      the HM block minimal
- [ ] Same module works for NIXPC and ASAHI without per-host HM duplication?