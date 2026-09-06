# attrs — machine-class bundles

## Purpose
Composable NixOS module bundles that group system modules + feature sets by machine class. Hosts import one `attrs` bundle plus host-specific extras, instead of listing every system module individually.

## Ownership
- `desktop/` — core desktop base: `core` + `network` + `audio` + `homeManager` + `act` + `waylandBase`, `allowUnfree = true`, shared `environment.systemPackages` (CLI tools, `obsidian`, `ffmpeg`, `tailscale`, `cachix`, `jj`, etc.; see `desktop/default.nix:42`).
- `gaming/` — Steam bundle (`programs.steam` + compat) — imported by `NIXPC` alongside `gaming-tools`.
- `programming/` — system-side dev tools (HM side is `features/programming`).

## Local Contracts
- **Bundles are plain `nixosModule`s, not `moduleWithSystem`:** `desktop/default.nix:10` is intentionally plain so `pkgs` is the NixOS configured `pkgs` (honours `nixpkgs.config.allowUnfree`). `moduleWithSystem`'s `pkgs` is the raw `perSystem` set and would refuse unfree packages during eval.
- **Composition is via `self.nixosModules`:** bundles `imports = with self.nixosModules; [ core network audio homeManager … ]`.
- **`docker` comes through `act`:** `desktop → act → docker` provides the daemon. Hosts needing `mcpContainers` must not re-import `docker` (would duplicate `extraGroups`).
- **Runtimes/LSPs are not in `desktop`:** language runtimes (`jdk`, `python3`, `nodejs`, `deno`, `bun`) are per-project via `direnv` (`features/programming`); LSPs are inside `nvf`. Keeps `desktop` lean.
- **Naming:** `flake.nixosModules.<bundleName>` — `desktop`, `gaming`, `programming`.

## Work Guidance
- New bundle: create `attrs/<name>/default.nix` exporting `flake.nixosModules.<name>`; compose from `self.nixosModules` entries.
- Prefer adding a feature to the bundle over adding it to every host — hosts should stay short (bundle + a few host-specific modules).
- Keep `desktop`'s `environment.systemPackages` sorted and commented by role when it grows.

## Verification
- `nix-instantiate --parse modules/attrs/<name>/default.nix`
- `nix eval .#nixosConfigurations.<HOST>.config.environment.systemPackages --impure` — spot-check bundle contents via host eval.
