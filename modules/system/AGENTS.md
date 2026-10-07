# system — cross-host system modules

## Purpose
NixOS modules shared by every desktop host (or available to any host). Composed by `attrs/desktop` and by hosts directly. Owns machine facts, HM wiring, and OS-level services.

## Ownership
Each subdirectory is one system concern exporting `flake.nixosModules.<name>`:

- `core/` — base system bundle, `nix-settings.nix` (caches, keep in sync with `flake.nix:nixConfig`), `boot.nix`, `hardware.nix`, `locale.nix`, `user.nix`; defines `flake.lib.hardwareFromMachine`.
- `home-manager/` — wires `inputs.home-manager` into NixOS, sets `useGlobalPkgs`/`useUserPackages`/`backupFileExtension`, enables the default HM feature set (`nvf`, `agent-browser`, `herdr-web`, `herdr-web-ui`, `programming`, `fish`, `nushell`, `opencode`, `waylandBase`, `stylix`) for `config.dendritic.userName`. Keep this list in step with the `imports` there. The `omp` feature still ships in the flake, but no host imports it.
- `distributed-builds/` — the NIXPC build link. `builder.nix` exports `remoteBuilder` (imported by `hosts/NIXPC`), `client.nix` exports `distributedBuilds` (imported by `hosts/ASAHI`), and both import `_link.nix` for the shared account, key path, address, and host key.
- `network/`, `audio/`, `drivers/` (`asahi.nix`, `nvidia.nix`), `portals/`, `tailscale/`, `time-sync/`, `stability/`, `obs/`, `home-manager/` — one concern each. Declarative Flatpak ownership lives in `features/flatpak/`; `system/flatpak/` is gone, so this list no longer names it.
- `wayland.nix` — exports `flake.nixosModules.wayland`: the Wayland + XWayland toolkit (X11 and Wayland CLI tools, wlroots/Mango control tools, Qt and cursor glue, fcitx5 packaged but not enabled, graphics and decode diagnostics) plus the keychain pair (`polkit-gnome` agent, `services.gnome.gnome-keyring`, sudo and polkit auth caches). It imports `portals`, so it owns the portal stack for both hosts.

## Local Contracts
- **Naming:** `flake.nixosModules.<name>` matches the directory (e.g. `core`, `network`, `audio`, `homeManager`, `asahiPlatform`/`nvidiaDrivers` for drivers).
- **`core` is the root bundle:** `attrs/desktop` and hosts import `core`; `core/default.nix` itself composes submodules (`nix-settings`, `boot`, `hardware`, `locale`, `user`) via a local `modules` list — not via `hardwareFromMachine` (that is host-wired).
- **`hardwareFromMachine` lives in `core`:** `self.lib.hardwareFromMachine` is defined in `system/core/default.nix` but consumed in `hosts/*/default.nix` — not imported as a module directly.
- **`home-manager` module is `moduleWithSystem`-free for `desktop` but this module itself is plain:** it reads `config.dendritic.userName` to wire `home-manager.users.<name>`. It publishes no option-tree export for the editor any more: the `dendritic.nixdOptionTree` option existed only so nixd could complete this user's HM options, and nil (the current Nix LSP) evaluates the flake itself.
- **Cache lists are dual-homed:** `flake.nix:nixConfig.substituters`/`trusted-public-keys` and `system/core/nix-settings.nix` must stay in sync (handoff comment in both files).
- **`wayland.nix` is intentionally self-sufficient:** it ships the full Wayland/XWayland toolkit even where a feature (`mango`, `computer-use`, `clipboard`) already installs part of it. Do not deduplicate it against features; a duplicated package is cheap, a desktop whose debugging tools depend on an unrelated feature being enabled is not. Everything in its package list is *packaged*, not autostarted — only the polkit agent and gnome-keyring are services.
- **`wayland.nix` owns the portal stack for both hosts:** hosts import `wayland`, not `portals` directly. `portals` is still imported by `features/flatpak`, so it reaches hosts by that route too; the import is idempotent either way.
- **The keychain caches are time-boxed, never password-free:** `security.sudo.extraConfig` uses `lib.mkAfter` because nixpkgs already defines that string, and `security.polkit.settings.Polkitd.ExpirationSeconds` extends polkit's cache. `security.sudo.wheelNeedsPassword` stays on — the password is still required, just not retyped constantly. Do not wire an askpass helper that replays a stored password into sudo.
- **Build parallelism is pinned in `nix-settings.nix`, not `flake.nix`:** `max-jobs = 4` with `cores = 0`. NixOS's default (`max-jobs = auto`, `cores = 0`) oversells `nproc²` processes and degrades the box by context switching; `nixConfig` cannot carry these because they depend on the machine's core count. `cores = 0` is deliberate — NIXPC builds ASAHI's kernel over the distributed-builds link, and that one derivation needs the whole box. Revisit together with the RAM/cores of a new host, and never raise `max-jobs` without lowering the per-build core budget.
- **GC retention is a speed knob:** `programs.nh.clean.extraArgs` keeps 5 generations / 14 days. A collected path is a recompile on rollback, so narrowing this trades disk for build time.
- **The build link is one identity file:** `system/distributed-builds/_link.nix` holds the `remotebuild` account, the `/root/.ssh/remotebuild` key path, the tailnet name of the builder, and its base64 host key. Both halves import it, so neither can drift. Only the public key is committed; `sshKey` must name a real file and this repo is public, so the private key is installed by hand on ASAHI as root.
- **The builder must advertise every feature its work needs:** `nix.buildMachines.*.supportedFeatures` decides which derivations reach the builder. `big-parallel` is load-bearing — the Asahi kernel carries `requiredSystemFeatures = [ "big-parallel" ]`, so dropping it sends the bootchain back to the Mac.

## Work Guidance
- New cross-host concern: create `system/<name>/default.nix` exporting `flake.nixosModules.<name>`; compose into `core` if every host needs it, or leave standalone for opt-in via `hosts/*/default.nix`.
- Driver variants go under `system/drivers/` (`asahi.nix`, `nvidia.nix`) — keep platform-specific packages isolated.
- When adding a substituter/key, update both `flake.nix` and `system/core/nix-settings.nix`.
- `nix.buildMachines.*.publicHostKey` takes base64 of the whole public key line (`base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub`), because Nix tokenizes the machines file on whitespace and base64-decodes that field. Confirm a change with `nix build --impure --no-link --print-out-paths '.#nixosConfigurations.<HOST>.config.environment.etc."nix/nix.conf".source'`.

## Verification
- `nix-instantiate --parse modules/system/<name>/default.nix`
- `nix eval .#nixosConfigurations.<HOST>.config.<option> --impure` for the option the module sets.
- `nix flake check --impure` — hardware gate validates `hardwareFromMachine` branching.
