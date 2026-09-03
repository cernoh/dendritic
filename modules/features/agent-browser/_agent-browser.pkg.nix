# Agent-browser package — prebuilt Rust binary from GitHub releases.
#
# Upstream is a native Rust CLI (plus a Node wrapper) distributed as
# platform-specific binaries at `vercel-labs/agent-browser` releases.
# We fetch the matching binary for the current system directly — no cargo
# build, no npm.
#
# Version is pinned here; bump alongside hash updates. Hashes are SRI
# (`sha256-...` base64) from `nix store prefetch-file`.
#
# `_` prefix: raw package definition — import-tree must not auto-import it
{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  patchelf,
  openssl,
  zlib,
}:
let
  version = "0.36.0";

  sources = {
    "x86_64-linux" = {
      url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-x64";
      hash = "sha256-VtFRgeUeACE/kH/POXB8/Ha/qAT/IPWpNzZhxz+W3l4=";
    };
    "aarch64-linux" = {
      url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-linux-arm64";
      hash = "sha256-rrVWrdyjkDYBpDPeGsrTrOHJxh0XAIS/WNh1iEWZqZA=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-darwin-x64";
      hash = "sha256-RdmsBhp9cuYer/kFMm4uGTZfTa2xIULqLy122EaJxwg=";
    };
    "aarch64-darwin" = {
      url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-darwin-arm64";
      hash = "sha256-shBqs52wg457F3L38m92BRjeVtCQUxUMVvnd3xWvmX0=";
    };
  };

  srcInfo =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system for agent-browser: ${stdenv.hostPlatform.system}");

  srcSkills = fetchurl {
    url = "https://github.com/vercel-labs/agent-browser/archive/refs/tags/v${version}.tar.gz";
    hash = "sha256-1BQBWFLeAWXEalrb8EFZLd8y7nkNdJBh+u9stDwdPFk=";
  };
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version srcSkills;

  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeWrapper
    patchelf
  ];

  installPhase =
    if stdenv.hostPlatform.isLinux then
      let
        libPath = lib.makeLibraryPath [
          stdenv.cc.cc.lib
          openssl
          zlib
        ];
      in
      ''
        runHook preInstall
        install -Dm755 "$src" "$out/libexec/agent-browser"
        patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" "$out/libexec/agent-browser"
        makeWrapper "$out/libexec/agent-browser" "$out/bin/agent-browser" \
          --prefix LD_LIBRARY_PATH : "${libPath}"
        tar -xzf "${srcSkills}" -C "$TMPDIR"
        cp -r "$TMPDIR/agent-browser-${version}/skills" "$out/skills"
        cp -r "$TMPDIR/agent-browser-${version}/skill-data" "$out/skill-data"
        runHook postInstall
      ''
    else
      ''
        runHook preInstall
        install -Dm755 "$src" "$out/bin/agent-browser"
        tar -xzf "${srcSkills}" -C "$TMPDIR"
        cp -r "$TMPDIR/agent-browser-${version}/skills" "$out/skills"
        cp -r "$TMPDIR/agent-browser-${version}/skill-data" "$out/skill-data"
        runHook postInstall
      '';

  dontStrip = stdenv.hostPlatform.isLinux;
  dontPatchELF = stdenv.hostPlatform.isLinux;

  doInstallCheck = stdenv.hostPlatform.isLinux;
  installCheckPhase = ''
    export HOME="$TMPDIR"
    "$out/bin/agent-browser" --help >/dev/null
  '';

  meta = {
    description = "Browser automation CLI for AI agents (Vercel Labs)";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames sources;
    mainProgram = "agent-browser";
  };
}
