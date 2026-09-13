# OMP package — prebuilt binary from GitHub releases.
#
# Upstream `can1357/oh-my-pi` distributes platform-specific binaries at
# `github.com/can1357/oh-my-pi/releases`. We fetch the matching binary for
# the current system directly — no Rust/Bun build, no flake input.
#
# Strictly pinned: the in-tree package is `releases/download/v<pinnedVersion>`
# with a per-system SRI hash. It MUST stay pure — evaluating it impurely made
# every pure host eval fail, because `programs.omp` lands in `home.packages`
# and Home Manager's `.manpath` builds a `buildEnv` over those packages
# (issue #173). Currency comes from the activation-time fetch instead
# (`programs.omp.useLatestBinary`, see default.nix).
#
# To bump: read `SHA256SUMS.txt` from the release, convert each hex digest to
# SRI with `printf %s <hex> | xxd -r -p | base64`, and confirm the download
# with `nix store prefetch-file --json <url>` (its `hash` field is the SRI).
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
}:
let
  pinnedVersion = "18.1.19";

  pinnedSources = {
    "x86_64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-x64";
      hash = "sha256-S13wxhzJeCI70S9+jVM1VOgLs2CpGSSR3hPaPVOyg6w=";
    };
    "aarch64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-arm64";
      hash = "sha256-syG2uyqWBo3y9JcvmGVMI+RRNxonXPuwqY729fhY8jk=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-x64";
      hash = "sha256-Ez5MEfC6f5qTjQG9tPwMn/8n+JE0QOONTXI8teuEoXA=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-arm64";
      hash = "sha256-3vwdOY1qkPNJmNUSD7W1PPeuCMEN/5G4NMq1o7BGERk=";
    };
  };

  # glibc build on Linux, shipped pristine behind a loader wrapper — see
  # below. The `omp-linux-musl-*` assets are dynamically musl-linked
  # (`/lib/ld-musl-*`, `libc.musl-*.so.1`), not static, so they are no more
  # portable on NixOS and stay unused.
  system = stdenv.hostPlatform.system;

  srcInfo = pinnedSources.${system} or (throw "Unsupported system for omp: ${system}");
in
stdenv.mkDerivation {
  pname = "omp";
  version = pinnedVersion;
  src = fetchurl {
    inherit (srcInfo) url hash;
  };

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
    description = "Oh My Pi — agentic coding harness (prebuilt binary, pinned release)";
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
