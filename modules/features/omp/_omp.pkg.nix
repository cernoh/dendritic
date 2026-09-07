# OMP package — prebuilt binary from GitHub releases.
#
# Upstream `can1357/oh-my-pi` distributes platform-specific binaries at
# `github.com/can1357/oh-my-pi/releases`. We fetch the matching binary for
# the current system directly — no Rust/Bun build, no flake input.
#
# Auto-update (impure): when `autoUpdate = true` (default, requires
# `--impure` — dendritic's verification ladder already uses it), the
# package fetches `releases/latest/download/<asset>` impurely via
# `builtins.fetchurl` without a pinned hash, so every `nixos-rebuild` /
# `nix build` pulls the newest release without bumping hashes.
# When `autoUpdate = false`, a pinned `version` + SRI `hash` is used
# (reproducible, for `nix flake check` pure eval if needed).
#
# To pin manually: query `https://api.github.com/repos/can1357/oh-my-pi/releases/latest`
# (`browser_download_url` assets + `SHA256SUMS.txt` hex digests) and convert
# hex digests to SRI: `echo <hex> | xxd -r -p | base64` -> `sha256-<b64>`.
# (Verify with `nix hash file --sri <downloaded-file>`.)
#
# Linux note: upstream Linux binaries are Bun single-file executables. They
# must be shipped PRISTINE — rewriting INTERP/RPATH with patchelf corrupts
# the embedded payload lookup and the binary segfaults at startup (even
# `ldd` crashes on a patchelf'd copy, while the pristine binary runs fine
# under the Nix glibc loader). So on Linux we install the untouched binary
# as `$out/share/omp/omp.bin` plus a `$out/bin/omp` wrapper that execs it
# through `stdenv.cc.bintools.dynamicLinker --library-path ...` (NixOS has
# no `/lib`). Never patchelf this binary back.
#
# `_` prefix: raw package definition — import-tree must not auto-import it
# as a flake-parts module; features/omp/default.nix callPackages it.
{
  lib,
  stdenv,
  fetchurl,
  autoUpdate ? true,
}:
let
  pinnedVersion = "18.1.13";

  pinnedSources = {
    "x86_64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-x64";
      hash = "sha256-O+WjCMyR5va7oUgXX75lHTWD/20yriIcuTHcCKZOHzk=";
    };
    "aarch64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-arm64";
      hash = "sha256-BvxyGDygxbOt19HcwaMAXhe5tntnnwS1xkawi/52PLY=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-x64";
      hash = "sha256-Ik7kD6r/kHNZUEdJlC0N9HhguWuoCYylEnOEVUcH9Io=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-arm64";
      hash = "sha256-pMXJzFuCIhhNDXQpsLtqwqkrvkXdEb9o5LE2AFB5GQk=";
    };
  };

  # Asset name for `releases/latest/download` (glibc build on Linux;
  # shipped pristine behind a loader wrapper — see below. The
  # `omp-linux-musl-*` assets are dynamically musl-linked
  # (`/lib/ld-musl-*`, `libc.musl-*.so.1`), not static, so they are no
  # more portable on NixOS and stay unused).
  latestAssets = {
    "x86_64-linux" = "omp-linux-x64";
    "aarch64-linux" = "omp-linux-arm64";
    "x86_64-darwin" = "omp-darwin-x64";
    "aarch64-darwin" = "omp-darwin-arm64";
  };

  system = stdenv.hostPlatform.system;

  # Impure latest fetch: no hash, always pulls newest release.
  # Requires `--impure` (dendritic deploys already use it via hardwareFromMachine).
  latestSrc =
    let
      asset = latestAssets.${system} or (throw "Unsupported system for omp: ${system}");
      url = "https://github.com/can1357/oh-my-pi/releases/latest/download/${asset}";
    in
    builtins.fetchurl { inherit url; };

  pinnedSrcInfo = pinnedSources.${system} or (throw "Unsupported system for omp: ${system}");

  # Version string: for impure latest, try to read tag from GitHub API
  # (impure, best-effort); fallback to "latest" if API fetch fails
  # (e.g. offline or pure eval).
  latestVersion =
    let
      apiUrl = "https://api.github.com/repos/can1357/oh-my-pi/releases/latest";
      attempt = builtins.tryEval (
        let
          raw = builtins.readFile (builtins.fetchurl { url = apiUrl; });
          json = builtins.fromJSON raw;
        in
        lib.removePrefix "v" json.tag_name
      );
    in
    if attempt.success then attempt.value else "latest";

  version = if autoUpdate then latestVersion else pinnedVersion;

  src =
    if autoUpdate then
      latestSrc
    else
      fetchurl {
        inherit (pinnedSrcInfo) url hash;
      };
in
stdenv.mkDerivation {
  pname = "omp";
  inherit version src;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Pristine binary + loader wrapper (see header): patchelf must not
    # touch this Bun single-file executable.
    mkdir -p $out/share/omp
    cp $src $out/share/omp/omp.bin
    chmod +x $out/share/omp/omp.bin
    cat > $out/bin/omp <<EOF
    #!${stdenv.shell}
    exec ${stdenv.cc.bintools.dynamicLinker} --library-path ${
      lib.makeLibraryPath [
        stdenv.cc.libc
        (lib.getLib stdenv.cc.cc)
      ]
    } $out/share/omp/omp.bin "\$@"
    EOF
    chmod +x $out/bin/omp
  ''
  + lib.optionalString (!stdenv.hostPlatform.isLinux) ''
    cp $src $out/bin/omp
    chmod +x $out/bin/omp
  ''
  + ''
    runHook postInstall
  '';

  # Prebuilt binary: keep as-is. dontPatchELF keeps stdenv fixup from
  # re-patching the pristine copy (which would segfault it).
  dontStrip = true;
  dontPatchELF = true;

  meta = {
    description = "Oh My Pi — agentic coding harness (prebuilt binary, auto-updating)";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "omp";
  };
}
