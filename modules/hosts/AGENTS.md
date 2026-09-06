# hosts — host presets

## Purpose
One directory per machine producing `flake.nixosConfigurations.<HOST>`. Assembles `self.nixosModules` bundles + features into a concrete NixOS system. Two hosts: `NIXPC` (`x86_64-linux`, MangoWM, NVIDIA) and `ASAHI` (`aarch64-linux`, Niri, Apple Silicon).

## Ownership
- `NIXPC/` — `default.nix` (system assembly), `nixpcConfiguration.nix` (host-specific NixOS config), `RESCUE.md` if present.
- `ASAHI/` — `default.nix`, `asahiConfiguration.nix`, `RESCUE.md`, `_noctalia-settings.nix` (per-host Noctalia settings).

## Local Contracts
- **Assembly is `nixosSystem`:** each `default.nix` calls `inputs.nixpkgs.lib.nixosSystem { system = "<arch>-linux"; modules = with self.nixosModules; [ … ]; }`.
- **`hardwareFromMachine` gate:** every host's first module is `(self.lib.hardwareFromMachine "<system>")` from `modules/system/core/default.nix`. On the native machine with `--impure`, it imports `/etc/nixos/hardware-configuration.nix` (real `fileSystems."/"` by-uuid, `nixpkgs.hostPlatform` from hardware). Anywhere else (CI, other host, sandbox/`CI=1`/`NIX_BUILD_TOP`) it uses a placeholder root fs — evaluation succeeds, deploy does not. The `verify.nix` hardware gate enforces this.
- **`--impure` required for deploy:** `sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#<HOST>` — evaluated elsewhere shows the documented placeholder warning.
- **Shared base is `desktop`:** both hosts import `desktop` (from `attrs/desktop` → `core` + `network` + `audio` + `homeManager` + `act` + `waylandBase` + common `environment.systemPackages` + `allowUnfree`). Host `default.nix` then adds its compositor, drivers, and extras.
- **Per-host deltas:**
  - `NIXPC`: `nixpcConfiguration`, `nixpcDesktop`, `nvidiaDrivers`, `gaming`, `mango`, `noctaliaGreeter --session Mango`, `mcpContainers` (via `desktop→act→docker`; do not re-import `docker`).
  - `ASAHI`: `asahiConfiguration`, `asahiPlatform` (apple-silicon support), `widevine`, `niri`, `noctaliaGreeter --session Niri`, `stability`/`timeSync`/`tailscale`/`flatpak`/`obs`/`portals`.
- **`inputs.asahi` must follow nixpkgs** (`inputs.nixpkgs.follows = "nixpkgs"` in `flake.nix`) — otherwise apple-silicon packages resolve against the wrong `nixpkgs` and break cross-machine eval (issue #16).
- **Asahi bootchain is uncached** (`nixos-apple-silicon.cachix.org` excludes `linux-asahi`/`uboot-asahi`/`m1n1`) — every `asahi` input bump rebuilds ~4 heavy derivations locally; plan reboot via `/run/reboot-required` (issue #72/#73).

## Work Guidance
- New host: create `hosts/<HOST>/default.nix` with `flake.nixosConfigurations.<HOST>`; start from `NIXPC` or `ASAHI` template; always include `hardwareFromMachine` first.
- Per-host settings that differ (e.g. Noctalia): keep in `_noctalia-settings.nix` or similar `_*` file and import explicitly.
- Record rescue/rollback steps in `RESCUE.md` (see `ASAHI/RESCUE.md`).
- Do not duplicate `docker` module import — `act` already pulls it via `desktop`.

## Verification
- `nix-instantiate --parse modules/hosts/<HOST>/default.nix`
- `nix eval .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath --impure` (placeholder warning is expected off-machine)
- `nix run .#verify -- --host <HOST>` — hardware gate checks native vs cross-machine branch.
