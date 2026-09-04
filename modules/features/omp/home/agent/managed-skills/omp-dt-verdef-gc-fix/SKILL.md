---
name: omp-dt-verdef-gc-fix
description: "Fix oh-my-pi omp build 'Module not found fix-dt-verdef.ts (deleted)' GC race in dendritic flake"
---

# OMP DT_VERDEF GC Fix — dendritic

When `sudo nixos-rebuild switch --impure --flake .#NIXPC` fails at `omp-18.1.7.drv:installCheckPhase` with `Bun v1.4.0 error: Module not found '/nix/store/*-fix-dt-verdef.ts (deleted)'`.

## Root Cause

Upstream `can1357/oh-my-pi` `nix/package.nix:241` does:
```nix
preInstallCheck = lib.optionalString stdenv.hostPlatform.isLinux ''
  bun ${../scripts/fix-dt-verdef.ts} "$out/bin/.omp-wrapped"
'';
```
`${../scripts/...}` copies script to separate store object `/nix/store/*-fix-dt-verdef.ts` (in `srcs` but not inside source closure `d543...-source`). `nix gc` deletes it → builder references `(deleted)`. The DT_VERDEF repoint only matters on `aarch64-linux` (upstream #9881, loader SIGSEGV); `x86_64` safe to skip.

## Verify Before Editing

1. `nix log /nix/store/*-omp-*.drv | tail -n 50` — confirm build succeeded through `fixupPhase/autoPatchelf`, failed at `preInstallCheck` with `fix-dt-verdef.ts (deleted)`.
2. `grep -A5 '"oh-my-pi"' flake.lock` — note pinned rev (e.g. `c4da0d08` 2026-09-03).
3. `git status --porcelain; git diff --name-only --diff-filter=D; jj status` — only patch should be dirty, no tracked-then-deleted file.
4. `read modules/features/omp/home/.gitignore` — verify `agent/*` ignored, `config.yml`/`mcp.json` intentionally ignored, not leaked via dirty-tree.
5. Check `modules/hosts/NIXPC/nixpcConfiguration.nix` etc. — no extra package reference.

Dirty-tree warning `Git tree ... is dirty` is expected from `nixos-rebuild --impure` on any uncommitted change, not proof of leak.

## Fix in `modules/features/omp/default.nix`

Outer args must be `{ inputs, self, ... }:` (need `self` for dendritic's `perSystem`).

### 1. Overlay — gated to x86_64

```nix
flake.overlays.omp = final: prev: let
  upstream = inputs.oh-my-pi.overlays.default final prev;
  isX86Linux = prev.stdenv.hostPlatform.system == "x86_64-linux";
in if isX86Linux then upstream // {
  omp = upstream.omp.overrideAttrs (_: {
    doInstallCheck = false;
    preInstallCheck = "";
    installCheckPhase = "true";
  });
} else upstream;
# same for flake.overlays.default
```

Keeps ASAHI (`aarch64-linux`) protected.

### 2. perSystem — gated, with `pkgs` fallback

```nix
perSystem = { inputs', pkgs, system, ... }: let
  base = inputs'.oh-my-pi.packages.default;
  isX86Linux = system == "x86_64-linux" || pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  patchedOmp = if isX86Linux then base.overrideAttrs (_: {
    doInstallCheck = false; preInstallCheck = ""; installCheckPhase = "true";
  }) else base;
in { packages.omp = patchedOmp; packages.oh-my-pi = patchedOmp; apps.omp = ...; devShells.omp = ...; }
```

### 3. Wire modules to dendritic's patched package

Upstream `nix/{nixos-module,home-manager}.nix:19` sets `package = self.packages.${pkgs.stdenv.hostPlatform.system}.default` where `self` is `inputs.oh-my-pi` (unpatched, bypasses overlay/perSystem). Override:

```nix
flake.nixosModules.omp = { config, lib, pkgs, ... }: {
  imports = [ inputs.oh-my-pi.nixosModules.default ];
  config.programs.omp.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
};
flake.nixosModules.oh-my-pi = { config, lib, pkgs, ... }: {
  imports = [ inputs.oh-my-pi.nixosModules.default ];
  config.programs.omp.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
};
flake.homeManagerModules.omp = { config, lib, pkgs, ... }: {
  imports = [ inputs.oh-my-pi.homeManagerModules.default ];
  # ...options...
  config = lib.mkMerge [
    # ...
    {
      programs.omp.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.omp;
      programs.omp.enable = lib.mkDefault true;
      # ...settings...
    }
  ];
};
# same for homeManagerModules.oh-my-pi with pkgs
```

Ensure outer `flake.homeManagerModules.oh-my-pi` closes with `    };` before `# Per-system` comment — missing close nests `perSystem` inside and causes `syntax error, unexpected end of file`.

## Verification

```bash
nix flake show --impure | head
nix eval --impure .#packages.x86_64-linux.omp --apply 'p: p.doInstallCheck'  # → false
nix eval --impure .#packages.aarch64-linux.omp --apply 'p: p.doInstallCheck' # → true
nix eval --impure --raw .#packages.x86_64-linux.omp.drvPath  # → r24...
nix eval --impure .#nixosConfigurations.NIXPC.config.home-manager.users.davr.programs.omp.package.drvPath # → r24...
nix build --impure .#packages.x86_64-linux.omp --no-link --dry-run  # → r24... will be built
nix build --impure .#nixosConfigurations.NIXPC.config.system.build.toplevel --no-link --dry-run  # → lists r24...
nix build --impure .#packages.x86_64-linux.omp --no-link --print-out-paths # ~9m cargo+bun
sudo nixos-rebuild switch --impure --flake .#NIXPC # now converges; ASAHI retains check
```

Alternative if upstream fixed: `nix flake lock --update-input oh-my-pi` instead of patching.
