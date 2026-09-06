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
# and convert hex digests to SRI: `nix store prefetch-file <url>` or
# `echo <hex> | xxd -r -p | base64` -> `sha256-<b64>`.
#
# `_` prefix: raw package definition — import-tree must not auto-import it
# as a flake-parts module; features/omp/default.nix callPackages it.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  autoUpdate ? true,
}:
let
  pinnedVersion = "18.1.12";

  pinnedSources = {
    "x86_64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-x64";
      hash = "sha256-9UMQCPcdLzlxYXIFz86csifB0TVmWTAIgkTHbYay+0I=";
    };
    "aarch64-linux" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-linux-arm64";
      hash = "sha256-Eox5SY5bnTKF1Xt7Q9RhOarVRzpph2cxT/vmDHxd4xQ=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-x64";
      hash = "sha256-81tW7DnIlMf0N6LROo7lrFGp/GXvLEozu8TsnGMznLU=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${pinnedVersion}/omp-darwin-arm64";
      hash = "sha256-fP2Q4LPz/25KlJMUsBBF8ZyyXy8tnYXDxkvORwS+hn0=";
    };
  };

  # Asset name for `releases/latest/download` (glibc build on Linux;
  # its ELF interpreter is patched to the Nix store libc below — musl
  # assets are Alpine-linked and unresolvable on NixOS).
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
    cp $src $out/bin/omp
    # Fetched sources are mode 444; patchelf below needs write access.
    chmod u+w $out/bin/omp
  ''
  + lib.optionalString (stdenv.hostPlatform.isLinux && stdenv.hostPlatform.libc == "glibc") ''
    # Upstream Linux assets are dynamically linked and request
    # /lib64/ld-linux-*.so.* — absent on NixOS. Repoint the interpreter
    # at the stdenv libc loader and rpath it into the same libc (its
    # only NEEDED family). The probe skips statically linked assets,
    # which need no fixup.
    loader=$(echo ${stdenv.cc.libc.out}/lib/ld-linux-*.so*)
    if ${patchelf}/bin/patchelf --print-interpreter $out/bin/omp >/dev/null 2>&1; then
      ${patchelf}/bin/patchelf \
        --set-interpreter "$loader" \
        --set-rpath "${stdenv.cc.libc.out}/lib" \
        $out/bin/omp
    fi
  ''
  + ''
    chmod +x $out/bin/omp
    runHook postInstall
  '';

  # Prebuilt binary: keep as-is; the interpreter fixup above is the only
  # mutation. dontPatchELF keeps stdenv fixup from re-patching.
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
