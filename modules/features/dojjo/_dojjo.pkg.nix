# Dojjo package — built from source (no Nix flake upstream).
#
# Upstream is a Dart CLI in `cli/` (monorepo root is `cli/`, not repo root).
# We vendor the source via flake input `dojjo` (flake = false, tag v0.2.2,
# mirrors stremio-kai pattern) and build with `buildDartApplication`.
# `src = "${src}/cli"` points at the Dart package root; `pubspec.lock`
# is vendored as JSON (`pubspec.lock.json`) so offline deps work without
# `autoPubspecLock` network. Generated `*.freezed.dart`/`*.g.dart` for Dart
# 3.13 are vendored in `generated/` (upstream 3.11 is stale for `changeId`).
#
# `_` prefix: raw package definition — import-tree must not auto-import it as
# a flake-parts module; features/dojjo/default.nix callPackages it.
{
  lib,
  buildDartApplication,
  src,
}:
let
  version = "0.2.2";
  cliSrc = "${src}/cli";
in
buildDartApplication {
  pname = "dojjo";
  inherit version;

  src = cliSrc;
  pubspecLock = lib.importJSON ./pubspec.lock.json;

  doCheck = false;

  # Vendored `build_runner` output for Nixpkgs Dart 3.13. Upstream's
  # checked-in `*.freezed.dart`/`*.g.dart` are for 3.11 and miss
  # `changeId`/`copyWith` on WorkspaceInfo, causing AOT compile to fail.
  postPatch = ''
    cp ${./generated/jj.freezed.dart} lib/src/jj.freezed.dart
    cp ${./generated/jj.g.dart} lib/src/jj.g.dart
    cp ${./generated/config.freezed.dart} lib/src/config.freezed.dart
    cp ${./generated/config.g.dart} lib/src/config.g.dart
  '';

  # Ensure both `djo` and `dojjo` aliases exist and install shell
  # completions. `pubspec.yaml` declares `executables: djo: djo, dojjo: djo`
  # but be explicit for robustness.
  postInstall = ''
    if [ ! -e $out/bin/dojjo ]; then
      ln -s $out/bin/djo $out/bin/dojjo
    fi
    mkdir -p $out/share/bash-completion/completions
    mkdir -p $out/share/zsh/site-functions
    mkdir -p $out/share/fish/vendor_completions.d
    $out/bin/djo shell completion bash > $out/share/bash-completion/completions/djo 2>/dev/null || true
    $out/bin/djo shell completion zsh > $out/share/zsh/site-functions/_djo 2>/dev/null || true
    $out/bin/djo shell completion fish > $out/share/fish/vendor_completions.d/djo.fish 2>/dev/null || true
    ln -sf djo $out/share/bash-completion/completions/dojjo 2>/dev/null || true
    ln -sf _djo $out/share/zsh/site-functions/_dojjo 2>/dev/null || true
    ln -sf djo.fish $out/share/fish/vendor_completions.d/dojjo.fish 2>/dev/null || true
  '';

  meta = {
    description = "Workspace manager for jj (Jujutsu) — worktrunk-inspired, with hooks and shell integration";
    homepage = "https://github.com/tjarvstrand/dojjo";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
    mainProgram = "djo";
  };
}
