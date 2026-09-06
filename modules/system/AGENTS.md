# system — cross-host system modules

## Purpose
NixOS modules shared by every desktop host (or available to any host). Composed by `attrs/desktop` and by hosts directly. Owns machine facts, HM wiring, and OS-level services.

## Ownership
Each subdirectory is one system concern exporting `flake.nixosModules.<name>`:

- `core/` — base system bundle, `nix-settings.nix` (caches, keep in sync with `flake.nix:nixConfig`), `boot.nix`, `hardware.nix`, `locale.nix`, `user.nix`; defines `flake.lib.hardwareFromMachine`.
- `home-manager/` — wires `inputs.home-manager` into NixOS, sets `useGlobalPkgs`/`useUserPackages`/`backupFileExtension`, enables the default HM feature set (`nvf`, `omp`, `agent-browser`, `programming`, `fish`, `nushell`, `opencode`, `waylandBase`) for `config.dendritic.userName`.
- `network/`, `audio/`, `drivers/` (`asahi.nix`, `nvidia.nix`), `flatpak/`, `portals/`, `tailscale/`, `time-sync/`, `stability/`, `obs/`, `home-manager/` — one concern each.

## Local Contracts
- **Naming:** `flake.nixosModules.<name>` matches the directory (e.g. `core`, `network`, `audio`, `homeManager`, `asahiPlatform`/`nvidiaDrivers` for drivers).
- **`core` is the root bundle:** `attrs/desktop` and hosts import `core`; `core/default.nix` itself composes submodules (`nix-settings`, `boot`, `hardware`, `locale`, `user`) via a local `modules` list — not via `hardwareFromMachine` (that is host-wired).
- **`hardwareFromMachine` lives in `core`:** `self.lib.hardwareFromMachine` is defined in `system/core/default.nix` but consumed in `hosts/*/default.nix` — not imported as a module directly.
- **`home-manager` module is `moduleWithSystem`-free for `desktop` but this module itself is plain:** it reads `config.dendritic.userName` to wire `home-manager.users.<name>`.
- **Cache lists are dual-homed:** `flake.nix:nixConfig.substituters`/`trusted-public-keys` and `system/core/nix-settings.nix` must stay in sync (handoff comment in both files).

## Work Guidance
- New cross-host concern: create `system/<name>/default.nix` exporting `flake.nixosModules.<name>`; compose into `core` if every host needs it, or leave standalone for opt-in via `hosts/*/default.nix`.
- Driver variants go under `system/drivers/` (`asahi.nix`, `nvidia.nix`) — keep platform-specific packages isolated.
- When adding a substituter/key, update both `flake.nix` and `system/core/nix-settings.nix`.

## Verification
- `nix-instantiate --parse modules/system/<name>/default.nix`
- `nix eval .#nixosConfigurations.<HOST>.config.<option> --impure` for the option the module sets.
- `nix flake check --impure` — hardware gate validates `hardwareFromMachine` branching.
