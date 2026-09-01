# Dojjo package — binary vendor with Dart source fallback.
#
# Upstream publishes prebuilt AOT Dart binaries (no Nix flake). install.sh
# fetches `djo-linux-x64` / `djo-macos-arm64` from GitHub releases; this
# derivation vendors the same artifacts via fetchurl for the hosts that have
# them (x86_64-linux, aarch64-darwin) so the build is pure and fast.
# For this iteration the binary for x86_64-linux is temporarily disabled
# (upstream 0.2.2 artifact behaves as `dartaotruntime` on NixOS — see
# investigation in PR) so all Linux builds use the Dart source path below.
# The source comes from the `dojjo` flake input (flake = false, tag v0.2.2);
# its `cli/` subdir is the Dart package root. The pubspec.lock is vendored
# as JSON via `pubspec.lock.json` so the build is pure.
#
# `_` prefix: raw package definition — import-tree must not auto-import it as
# a flake-parts module; features/dojjo/default.nix callPackages it.
{
  lib,
  stdenv,
  fetchurl,
  buildDartApplication,
  src,
}:
let
  version = "0.2.2";

  binaries = {
    # x86_64-linux temporarily disabled — see above.
    "aarch64-darwin" = {
      url = "https://github.com/tjarvstrand/dojjo/releases/download/v${version}/djo-macos-arm64";
      hash = "sha256-zNMpIwtiJn5Y+P21mPyhIx5lwNlhDZugH+O/v4dwFZg=";
    };
  };

  system = stdenv.hostPlatform.system;
  cliSrc = "${src}/cli";
in
if builtins.hasAttr system binaries then
  stdenv.mkDerivation {
    pname = "dojjo";
    inherit version;

    src = fetchurl {
      inherit (binaries.${system}) url hash;
    };

    dontUnpack = true;
    dontStrip = true;
    dontPatchELF = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp $src $out/bin/djo
      chmod +x $out/bin/djo
      ln -s $out/bin/djo $out/bin/dojjo
      runHook postInstall
    '';

    meta = {
      description = "Workspace manager for jj (Jujutsu) — worktrunk-inspired, with hooks and shell integration";
      homepage = "https://github.com/tjarvstrand/dojjo";
      license = lib.licenses.mit;
      platforms = lib.attrNames binaries;
      mainProgram = "djo";
    };
  }
else
  buildDartApplication {
    pname = "dojjo";
    inherit version;

    src = cliSrc;
    pubspecLock = lib.importJSON ./pubspec.lock.json;

    doCheck = false;

    # Vendored `build_runner` output for Nixpkgs Dart 3.13. Upstream's
    # checked-in `*.freezed.dart`/`*.g.dart` are for 3.11 and miss
    # `changeId`/`copyWith` on WorkspaceInfo, causing AOT compile to fail.
    # Regenerated locally with `dart run build_runner build` (see
    # generated/README.md) and vendored here so the build stays pure.
    postPatch = ''
      cp ${./generated/jj.freezed.dart} lib/src/jj.freezed.dart
      cp ${./generated/jj.g.dart} lib/src/jj.g.dart
      cp ${./generated/config.freezed.dart} lib/src/config.freezed.dart
      cp ${./generated/config.g.dart} lib/src/config.g.dart
    '';

    meta = {
      description = "Workspace manager for jj (Jujutsu) — worktrunk-inspired, with hooks and shell integration (built from source)";
      homepage = "https://github.com/tjarvstrand/dojjo";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
      mainProgram = "djo";
    };
  }
