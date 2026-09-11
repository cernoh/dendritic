# modules — dendritic flake-parts tree

## Purpose
All flake-parts modules auto-registered by `import-tree` from `flake.nix:84` (`inputs.import-tree ./modules`). Every `*.nix` under this tree is a flake-parts module. Defines hosts, features, system concerns, bundles, and verification gates.

## Ownership
- `parts.nix` — shared flake-parts plumbing.
- `verify.nix` — verification gates.
- `attrs/` — machine-class bundles.
- `features/` — opt-in feature modules.
- `hosts/` — host presets producing `nixosConfigurations`.
- `system/` — cross-host system concerns.
- Subtree owners: see Child DOX Index.

## Local Contracts
- **Auto-registration:** every `*.nix` under `modules/` is imported as a flake-parts module. No manifest. A parse error in any file breaks the whole flake.
- **`_` exclusion:** paths containing `/_` are skipped by `import-tree`. Data-only siblings (`_languages.nix`, host `_*.nix`, `_*pkg.nix` derivations) use it and are imported explicitly by their owning module.
- **Lower-level modules are values:** features expose `flake.nixosModules.<name>` / `flake.homeManagerModules.<name>`; hosts assemble them by name (`self.nixosModules.<name>`).
- **Home-manager HM modules need declaration:** `parts.nix:14` declares `options.flake.homeManagerModules` as `lazyAttrsOf raw` so multiple files can merge into it.
- **Systems:** `parts.nix:2` — `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin`. Formatter: `nixfmt` (RFC style).
- **Impure eval:** `nix flake check --impure` / `nix run .#verify` — required because `hardwareFromMachine` reads `/etc/nixos/hardware-configuration.nix`.

## Work Guidance
- Check new files before commit: `nix-instantiate --parse <file>`.
- Keep `flake.nix` `nixConfig` and `modules/system/core/nix-settings.nix` substituter lists in sync.
- New top-level concerns go in `system/`; new apps go in `features/`; new machine classes in `attrs/`.

## Verification
- `nix-instantiate --parse modules/<path>` — parse gate.
- `nix eval .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath --impure` — host eval.
- `nix flake check --impure` — full ladder (`verify.nix`: parse, eval-pure, hardware, fmt, aggregate).
- `nix run .#verify -- --host <HOST>` — same gates outside sandbox.

## Child DOX Index
- `attrs/` — machine-class bundles composing features by name → `modules/attrs/AGENTS.md`
- `features/` — opt-in feature modules (import = enable) → `modules/features/AGENTS.md`
- `hosts/` — host presets (`NIXPC`, `ASAHI`) → `modules/hosts/AGENTS.md`
- `system/` — cross-host system modules (core, network, audio, drivers, …) → `modules/system/AGENTS.md`
