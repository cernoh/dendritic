---
name: nix-hermetic-deno-compile
description: "Compile a Deno script to a release binary inside a Nix derivation with no network: vendor the per-arch denort zip via fetchurl and pre-seed $DENO_DIR/dl/release/ver/. Use when adding a deno compile derivation to a flake or hitting 'dns error' / 'error sending request' for dl.deno.land in a nix build sandbox."
---

# Hermetic `deno compile` in a Nix derivation

`deno compile` downloads a per-arch `denort` base binary from
`https://dl.deno.land/release/v<deno-ver>/denort-<triple>.zip` on first
use. Nix build sandboxes have no DNS, so this fails with
`dns error ... dl.deno.land` unless the zip is vendored.

## Facts

- Deno caches the zip at `$DENO_DIR/dl/release/<deno-ver>/denort-<triple>.zip`
  (plain URL-mirror path — verify with a networked compile into a scratch
  `DENO_DIR` if a new deno version changes the layout).
- Triple = `pkgs.stdenv.hostPlatform.rust.rustcTarget`
  (`x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu`).
- Derivation must be per-system (e.g. `forEachSystem`) or the arch
  hardcodes; map triple -> sha256 for every supported system.

## Recipe

```nix
releasePkg = pkgs:
  let
    triple = pkgs.stdenv.hostPlatform.rust.rustcTarget;
    denortHashes = {
      "x86_64-unknown-linux-gnu" = "sha256-…";
      "aarch64-unknown-linux-gnu" = "sha256-…";
    };
    denort = pkgs.fetchurl {
      url = "https://dl.deno.land/release/v${pkgs.deno.version}/denort-${triple}.zip";
      sha256 = denortHashes.${triple};
    };
  in
  pkgs.stdenv.mkDerivation {
    pname = "…-release";
    version = "git";
    src = ./scripts;
    nativeBuildInputs = [ pkgs.deno ];
    buildPhase = ''
      runHook preBuild
      export DENO_NO_UPDATE_CHECK=1
      export DENO_DIR="$TMPDIR/deno-cache"
      mkdir -p "$DENO_DIR/dl/release/v${pkgs.deno.version}"
      cp "${denort}" "$DENO_DIR/dl/release/v${pkgs.deno.version}/denort-${triple}.zip"
      deno compile --allow-… --output stremio-accru-linux desktop/main.ts
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 stremio-accru-linux "$out/bin/stremio-accru-linux"
      runHook postInstall
    '';
  };
```

## Hash pinning when nixpkgs bumps deno

```sh
nix store prefetch-file --json \
  'https://dl.deno.land/release/v<new-ver>/denort-aarch64-unknown-linux-gnu.zip'
```

## Do NOT

- `__noChroot`, `--option sandbox false`, or network in buildPhase — the
  vendored fixed-output fetchurl keeps the build hermetic.
- NixOS-only patchelf (interpreter/rpath) inside a package meant for
  release artifacts: that pins the binary to the nix store. Keep the
  NixOS wrapper (`writeShellApplication` + patchelf) separate from the
  generic-Linux release derivation.

## Verify

- `nix build .#<pkg>` green; `file result/bin/…` shows a generic ELF with
  `/lib64/ld-linux-x86-64.so.2` and no nix-store interpreter/rpath.
- Per-system wiring: `nix derivation show .#packages.<system>.<pkg>` and
  check the `cp` line in `env.buildPhase` references the right
  `denort-<triple>.zip` store path.
- Runtime smoke on NixOS host is impossible (stub-ld) for generic
  binaries; the CI runner / generic distro is the runtime proof.
