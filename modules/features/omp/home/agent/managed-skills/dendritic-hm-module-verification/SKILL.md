---
name: dendritic-hm-module-verification
description: "Verify a dendritic flake's homeManagerModules.name output without a host config: standalone HM eval with stateVersion shim, finalPackage build, headless nvim smoke test, whole-flake checks"
---

# Verify a home-manager feature module in the dendritic flake

Recipe used to verify `modules/features/nvf` (PR cernoh/dendritic#2). Use whenever a
dendritic feature exposes a `flake.homeManagerModules.<name>` output — there is no host
config in the flake yet to consume it, so verify standalone.

All commands run from the flake root (`~/.config/dendritic`). If substitution is broken,
prefix with `NIX_CONFIG="substituters = https://cache.nixos.org"` (see managed skill
`nix-substitution-silently-broken`).

## 1. Parse + eval

```bash
nix-instantiate --parse modules/features/<name>/*.nix   # each file
```

Standalone HM eval (no host needed). Shim module supplies required `home.*` basics;
unfree allowed because plugins often pull unfree deps (e.g. copilot-language-server):

```nix
nix-instantiate --eval --json --strict --impure --expr '
let
  flake = builtins.getFlake "/home/davr/.config/dendritic";
  pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
in (flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;
  modules = [
    flake.homeManagerModules.nvf            # <- module under test
    { home.stateVersion = "25.05"; home.username = "test"; home.homeDirectory = "/tmp/test"; }
  ];
}).config.programs.nvf' # then drill into .settings / .finalPackage
```

Without the shim you get `home.stateVersion ... has no value defined`; without allowUnfree
you get an unfree-license error at `finalPackage` — both are consumer-side, not module bugs.

## 2. Build the real artifact

```bash
nix build --impure --no-link --print-out-paths --expr '<same expr>.config.programs.nvf.finalPackage'
```

Watch the plan: "these N derivations will be built" should be SMALL (wrapper/init scripts,
plugins). Hundreds of core packages (bash, glibc) = substitution is silently off.

## 3. Smoke-test behavior

Headless launch through the full generated config:

```bash
<out>/bin/nvim --headless '+lua vim.defer_fn(function() print("NVIM_HEADLESS_OK") vim.cmd("qa!") end, 3000)'
```

If a build of the editor itself is blocked but pure evaluation works, extract and
syntax-check the generated Lua instead:

```bash
nix-instantiate --eval --raw --impure --expr '<expr>.settings.mnw.initLua' > /tmp/init.lua
luajit -e 'assert(loadfile("/tmp/init.lua")); print("LUA_SYNTAX_OK")'
```

(luajit lives inside any nvim closure: find one via `nix path-info -r $(readlink -f $(which nvim)) | grep luajit-env`.)

## 4. Whole-flake sanity

```bash
nix flake check        # warns "unknown flake output 'homeManagerModules'" — harmless
nix eval .#packages.x86_64-linux --apply builtins.attrNames   # no stray outputs from data files
```

Data siblings in a feature dir must be `_`-prefixed (import-tree skips `/_` paths);
verify they produced no flake outputs.
