---
name: dendritic-nix-flakes
description: "Creating, editing, composing, and verifying modules in dendritic-pattern Nix flakes (every file is a top-level flake-parts module auto-imported via import-tree); triggers on dendritic, import-tree, flake.nixosModules, moduleWithSystem work"
---

# Dendritic Nix Flakes

Work with dendritic-structured Nix flakes (https://github.com/mightyiam/dendritic). Reference configs: mightyiam/infra, voidarc/nixos (branch `dendritic`).

**Core invariant:** every `.nix` file except entry points (`flake.nix`, `default.nix`) is a top-level flake-parts module, auto-imported recursively by `import-tree`. File paths name features and carry NO other semantics — rename/move/split files freely with zero consequences.

## Canonical shape

```nix
# flake.nix — the ONLY file with special structure
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    # app inputs follow nixpkgs:
    # foo = { url = "github:..."; inputs.nixpkgs.follows = "nixpkgs"; };
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
```

Directory layout (voidarc convention; this local config mirrors it):

```
modules/
  parts.nix                    # {config.systems = ["x86_64-linux" ...];}
  features/<app>/default.nix   # one feature/app per dir: NixOS module + its package(s)
  system/<area>/...            # plain system modules (network, audio, locale) — no binaries
  attrs/<name>/default.nix     # bundles of other modules, no new features
  hosts/<HOST>/default.nix     # nixosConfigurations presets; output name = folder name
```

## Hard rules

1. **Never write cross-file `imports = [ ./other.nix ]` between top-level modules.** `import-tree` already imports everything; explicit relative imports duplicate modules and cause conflicts. Compose by output name instead.
2. New file = automatically registered; no manifest to update. Corollary: any file that fails to parse breaks the ENTIRE flake. Parse-check new files: `nix-instantiate --parse <file>`.
3. Lower-level modules (NixOS/home-manager/nix-darwin) are **values** stored under options, conventionally `flake.nixosModules.<name>`.
4. Files that are NOT top-level modules (`callPackage` derivations, raw data) MUST be excluded from auto-import: suffix `.pkg.nix` or place under a `_`-prefixed directory (import-tree skips paths containing `/_`).
5. Don't nest flake-parts modules incorrectly — flake-parts can't merge nested module sets. One attribute layer per concern (`flake.nixosModules.x`, `perSystem.packages.y`).

## The four module shapes

```nix
# 1. Feature with a wrapped package (needs self'/inputs'/per-system pkgs)
{inputs, moduleWithSystem, ...}: {
  flake.nixosModules.kitty = moduleWithSystem ({self', pkgs, ...}: {
    environment.systemPackages = [self'.packages.kitty];
  });
  perSystem = {pkgs, ...}: {
    packages.kitty = <derivation>;  # often built via inputs.wrappers
  };
}

# 2. Plain system module (only needs nixpkgs module args)
{...}: {
  flake.nixosModules.locale = {pkgs, lib, ...}: {
    time.timeZone = "Europe/London";
  };
}

# 3. Attr bundle — compose existing modules by name
{moduleWithSystem, ...}: {
  flake.nixosModules.gaming = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [steam];
  in {imports = modules;});
}

# 4. Host preset → nixosConfigurations
{self, inputs, ...}: {
  flake.nixosConfigurations.HACKSTATION = inputs.nixpkgs.lib.nixosSystem {
    modules = with self.nixosModules; [desktop gaming davinci ...];
  };
}
```

### moduleWithSystem vs plain — the classic bug

- `moduleWithSystem ({pkgs, self', inputs', ...}: ...)`: args come from THIS flake's perSystem evaluation — use when the module references `self'.packages`, `inputs'.foo`, or needs overlay-customized `pkgs`.
- Plain `{pkgs, lib, ...}: {...}` stored as the value: args come from the LOWER-level (NixOS/HM) evaluation. Mixing instances means packages built against a different nixpkgs than the rest of the system.
- Escape hatch without wrapping: `self.packages.${pkgs.stdenv.hostPlatform.system}.name` inside a plain module.

## Adding a feature

Create `modules/features/<name>/default.nix` following shape 1. One file implements ONE feature across all config classes it applies to (NixOS + home-manager bits live together). Merge related content under one shared module name rather than one name per tiny module — long import lists are a smell. Importing IS enabling: don't add `enable` options to your own feature modules (upstream anti-pattern); only when a module is imported unconditionally but its feature is optional.

## Sharing values between files

Never thread values through `specialArgs`/`extraSpecialArgs`. Any top-level module can declare an option and write it; every other module reads it via top-level `config`:

```nix
options.flake.myValue = lib.mkOption {type = lib.types.raw;};
config.flake.myValue = ...;
```

Declare real options modeling your infra instead of stuffing generic stores.

## Verification

- Parse single file: `nix-instantiate --parse modules/new-file.nix`
- Whole-flake eval: `nix flake check` / `nix flake show`
- Build a host: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Rebuild (hosts referencing out-of-repo `hardware-configuration.nix` need `--impure`):
  `sudo nixos-rebuild switch --impure --flake .#<host>`
- Run a feature binary: `nix run .#<feature-name>`
- Inspect an option: `nix eval .#nixosConfigurations.<host>.config.<option.path>`
