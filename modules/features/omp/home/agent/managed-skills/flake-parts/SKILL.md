---
name: flake-parts
description: "Writing flake-parts modules: mkFlake, systems/perSystem, module arguments (self', inputs', withSystem, moduleWithSystem), reusable flakeModules, custom output attributes, and nixpkgs wiring. Use for any flake-parts Nix work, especially under the dendritic philosophy."
---

# flake-parts

Reference: https://flake.parts/ — docs, options reference (`/options/flake-parts`), and ecosystem module catalog.

`flake-parts` is a minimal mirror of the flake schema built on the Nix module system: `outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (module)`. The module system merges configuration; opinionated features live in ecosystem modules you `imports`. Under the **dendritic philosophy** every file (except entry points) is a top-level flake-parts module auto-imported by `import-tree` — see the `dendritic-nix-flakes` skill for layout and import-tree rules; this skill covers the flake-parts mechanics themselves.

## Core options

- `systems`: list of `"x86_64-linux"`-style strings enumerated into all per-system outputs. Default `[]`.
- `perSystem = {...}: {...}`: module evaluated once per configured system; its config becomes `flake.<attr>.<system>`. Define packages/devShells/apps/checks/formatter here.
  - `perSystem.packages`, `.legacyPackages`, `.devShells`, `.apps` (`{program, type="app", meta}`), `.checks` (built by `nix flake check`), `.formatter`, `.debug`
- Top level: `config`, `options`, `lib` (nixpkgs-lib), plus `getSystem`, `withSystem`, `moduleWithSystem`, and input args like `inputs`, `self`, `flake-parts-lib`.
- `flake.<attr>`: raw flake outputs (`nixosModules`, `nixosConfigurations`, `overlays`, ...). RFC42-style open submodule — arbitrary attrs allowed without declaration.
- `processedFlake`: read-only final output of `mkFlake`; post-process via the optional `touchup` module or set it directly.
- `perInput`: extensible function producing `inputs'.<name>` / `self'`; return small predictable attrsets to avoid polluting those namespaces.
- `transposition.<name>`: defines `flake.<name>.<system> = perSystem.<system>.<name>` plus the reverse in `perInput`. Avoid `adHoc = true`; declare the `perSystem.<name>` option yourself.
- Optional extras: `inputs.flake-parts.flakeModules.flakeModules` adds `flake.flakeModules` + `flakeModule` alias with deduplication/`disabledModules` support; other optionals include bundlers, easyOverlay, partitions, touchup, modules.
- Debugging: set `debug = true` to get `debug`, `allSystems`, `currentSystem` attrs for `nix repl` inspection (`currentSystem._module.args.pkgs.hello`).

## Module arguments

Only explicitly named parameters are passed (the module system uses `builtins.functionArgs`). Bare `args:` gets NOTHING; `args@{pkgs, ...}` binds args to an incomplete set — avoid `@` at the top level. In `@{...}` patterns only named attrs are populated.

Top-level:
```nix
getSystem "x86_64-linux"   # -> config of that system's perSystem
```

`withSystem` — enter one system's scope from top level (nixosConfigurations etc.):
```nix
{ withSystem, ... }: {
  flake.nixosConfigurations.host = withSystem "x86_64-linux" (ctx@{
      config,
      inputs',
      ...
    }:
      inputs.nixpkgs.lib.nixosSystem {
        modules = [({...}: {
          environment.systemPackages = [ctx.config.packages.hello];
        })];
      });
}
```

`moduleWithSystem` — wrap a lower-level module so IT can access per-system scope:
```nix
{moduleWithSystem, ...}: {
  flake.nixosModules.kitty =
    moduleWithSystem
    (
      perSys@{
        self',
        config,
      }:
        nixos@{...}: {
          environment.systemPackages = [perSys.self'.packages.kitty];
        }
    );
}
```

Inside `perSystem`:
- `pkgs` (default `inputs.nixpkgs.legacyPackages.${system}`, overridable via `_module.args.pkgs`)
- `inputs'` = inputs with system preselected: `inputs.foo.packages.x86_64-linux.bar` → `inputs'.foo.packages.bar`
- `self'` = self with system preselected: `packages.default = self'.packages.hello`
- `system` string itself

Cheat sheet — same value many ways: `config.packages.hello` ≡ `self'.packages.hello` (in perSystem); `(getSystem "x86_64-linux").packages.hello` ≡ `withSystem "x86_64-linux" ({config,...}: config.packages.hello)` (top level). Prefer `config.*` inside perSystem — reaches unexposed sub-options too.

## Getting started patterns

New flake: `nix flake init -t github:hercules-ci/flake-parts`.

Existing flake: add `flake-parts.url`, slide `mkFlake` between the outputs head and body:
```nix
outputs = inputs@{flake-parts, ...}:
  flake-parts.lib.mkFlake {inherit inputs;} ({
    imports = [
      # inputs.foo.flakeModules.default
    ];
    flake = {}; # original outputs here
    systems = ["x86_64-linux"];
    perSystem = {pkgs, ...}: {
      # packages.foo = pkgs.callPackage ./foo/package.nix {};
    };
  });
```

## Reusable modules (authoring best practices)

- Never assume/traverse `inputs` — user-controlled; traversing fetches everything transitively and breaks follows hygiene.
- Put options in a namespace named after your module: `perSystem.treefmt.programs`, not `perSystem.programs`.
- Integrate through `perSystem`, not just whole-flake interfaces — that's where users do build/test work ("perSystem first").
- Bundle the flakeModule in the same flake as the software it integrates.
- Configuration vs reusable module differ: shortcuts acceptable in a config surprise a module's users.
- Export as `flake.flakeModules.default` (alias `flakeModule`). If the module must also be used by the defining flake's own `imports`, put it in its own file/let-binding referenced both there and in the export (see "Dogfood a Reusable Module"); `flake.flakeModules` can't be read while defining the flake's own imports.

## Custom flake attribute

One-off: just set a value under `config.flake`. Reusable/integrating well: declare an option, ideally defined in `perSystem` then transposed to outputs (mirror upstream `modules/packages.nix`; or use internal `config.allSystems` when the pattern differs).

## Defining modules in separate files

Separate files lose lexical scope of `flake.nix`. Two fixes:
1. Factor out: bridge values into option definitions from the importing module (`services.foo.package = withSystem pkgs.stdenv.hostPlatform.system ({config, ...}: config.packages.default);`), keep specific options (`foo.package`, not `foo.flake`) for overridability.
2. `importApply ./file.nix { localFlake = self; inherit withSystem; }` where the file is `{localFlake, withSystem}: {lib, config, pkgs, ...}: {...}` (needs `flake-parts-lib`).

## NixOS + nixpkgs config

Two approaches (https://flake.parts/system):
1. Configure nixpkgs directly in NixOS (`nixpkgs.config.allowUnfree`, `nixpkgs.overlays`); pull packages via `withSystem pkgs.stdenv.hostPlatform.system ({config,...}: config.packages.foo)`. perSystem's pkgs stays unaware of these settings.
2. Configure `pkgs` ONCE in `perSystem._module.args.pkgs = import inputs.nixpkgs {...}`, reuse everywhere: `nixpkgs.pkgs = withSystem config.nixpkgs.hostPlatform.system ({pkgs, ...}: pkgs);` plus `inputs.nixpkgs.nixosModules.readOnlyPkgs` to lock it.

## Verification

- Parse single file: `nix-instantiate --parse <file>`
- Whole-flake eval: `nix flake check` / `nix flake show`
- Inspect options: `nix repl` → `:lf .` (or `debug = true`)
