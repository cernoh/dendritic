# funes package — prebuilt binary from the Hugging Face release bucket.
#
# Upstream `huggingface/funes` distributes platform binaries at
# `huggingface.co/buckets/huggingface/funes/resolve/v<tag>/`, each release
# tagged with a `SHA256SUMS` manifest. We fetch the asset for the current
# system directly — no flake input, no Rust build.
#
# Why not build from source: the crate links `lance`/`lance-index`
# (DataFusion + arrow 58) alongside `faer`, `tokenizers`, `safetensors` and
# `hf-hub`'s Xet client. That is a very large native build for a binary
# upstream already ships, and it would need OpenSSL plus its own toolchain
# fixes on aarch64 (`vendored-openssl`). The release asset is the supported
# distribution channel (`scripts/install.sh` is the first thing upstream
# documents), so it is what this flake consumes.
#
# Strictly pinned: the asset is `resolve/v<pinnedVersion>/<asset>` with a
# per-system SRI hash, derived from that release's `SHA256SUMS`. It MUST stay
# pure — it lands in `environment.systemPackages`, and impure evaluation of
# a package breaks the pure host eval gates. Currency is a pin bump, not an
# activation fetch: unlike `omp`, funes has no cheap "latest" indirection
# worth automating here, and a stale-but-working memory index is cheaper than
# a binary that moved under a live integration.
#
# To bump: read `SHA256SUMS` from
#   https://huggingface.co/buckets/huggingface/funes/resolve/v<new>/SHA256SUMS
# convert each hex digest to SRI with
#   printf %s <hex> | xxd -r -p | base64
# and confirm with `nix store prefetch-file --json <url>` (its `hash` field
# is the SRI). Upstream publishes only three assets; `x86_64-darwin` has none
# and throws, which is correct — neither host is Darwin.
#
# Linux note: this one is a plain Rust ELF and unlike omp's Bun binary it
# patches cleanly. `readelf -d` reports NEEDED for exactly `libc.so.6`,
# `libm.so.6`, `libgcc_s.so.1` and the loader, with a max symbol version of
# GLIBC_2.35 (upstream targets a 2.35 floor), so an explicit INTERP/RPATH
# rewrite onto the Nix glibc is all it takes (verified: `funes 1.6.0` under
# glibc 2.44). No `dontPatchELF`, no pristine-binary, no loader wrapper.
#
# The explicit patchPhase is REQUIRED, not belt-and-braces. nixpkgs does not
# do it for you: `fixupPhase` has no interpreter handling, and the only
# patchelf setup hook
# (development/tools/misc/patchelf/setup-hook.sh) merely `patchelf
# --shrink-rpath` over each ELF. `--set-interpreter` normally happens at link
# time via the nix cc wrapper's `-dynamic-linker`, which never runs for a
# prebuilt binary. Omitting this leaves `/lib64/ld-linux-x86-64.so.2` as the
# interpreter, which does not exist on NixOS, and every exec dies with
# "cannot execute: required file not found" — the installCheck below is what
# turns that into a build failure instead of a runtime surprise. The rewrite
# belongs in `preFixup`, not `patchPhase`: patchPhase runs before
# installPhase, so the binary does not exist yet and patchelf reports
# "No such file or directory".
#
# The interpreter and rpath come from stdenv's explicit attributes, NOT from
# $NIX_DYNAMIC_LINKER / $NIX_LDFLAGS. Inside a plain mkDerivation with no
# buildInputs both are traps: $NIX_DYNAMIC_LINKER is EMPTY (it exists only
# inside the cc-wrapper), and $NIX_LDFLAGS is merely `-rpath $out/lib`, so
# using it as an rpath VALUE hands patchelf a literal string beginning with
# "-rpath " — which SEGFAULTS patchelf instead of reporting a clean error. All
# three failures were hit on the way here; the values below are what work, and
# they are the idiom already used by features/omp/_omp.pkg.nix.
# The binary is ~216 MiB, which is the honest closure cost of carrying the
# embedding and rerank stacks: it is a fetch, not a build, but it is a large
# one.
#
# `_` prefix: raw package definition — import-tree must not auto-import it
# as a flake-parts module; features/funes/default.nix callPackages it.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
}:
let
  pinnedVersion = "1.6.0";

  pinnedSources = {
    "x86_64-linux" = {
      url = "https://huggingface.co/buckets/huggingface/funes/resolve/v${pinnedVersion}/funes-x86_64-linux";
      hash = "sha256-Tb1WPB1NRQntUXA0IxDiogNqOxstKLppMaJrrvkajPo=";
    };
    "aarch64-linux" = {
      url = "https://huggingface.co/buckets/huggingface/funes/resolve/v${pinnedVersion}/funes-aarch64-linux";
      hash = "sha256-2+65h3Fi/IqxUPgNX4gLgZA5utsfQeWDcDo+R6bwksE=";
    };
    "aarch64-darwin" = {
      url = "https://huggingface.co/buckets/huggingface/funes/resolve/v${pinnedVersion}/funes-arm64-apple-darwin";
      hash = "sha256-D9opXA90VgFq6wjBt3YyenWpbtjFAVyf0qtBb/UwcLU=";
    };
  };

  system = stdenv.hostPlatform.system;

  srcInfo =
    pinnedSources.${system}
      or (throw "funes has no upstream release asset for ${system}; upstream publishes x86_64-linux, aarch64-linux and arm64-apple-darwin only");
in
stdenv.mkDerivation {
  pname = "funes";
  version = pinnedVersion;
  src = fetchurl {
    inherit (srcInfo) url hash;
  };

  dontUnpack = true;

  # REQUIRED, and easy to miss: declaring patchelf pins a known version
  # (0.15.2) rather than whatever stdenv resolves. Not a bug fix — kept
  # because the rewrite below depends on patchelf behaviour for very large
  # ELFs.
  nativeBuildInputs = [ patchelf ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 0755 $src $out/bin/funes
    runHook postInstall
  '';

  # Runs at the START of fixupPhase, which is after installPhase (phase
  # order is unpack, patch, configure, build, install, fixup, installCheck)
  # — so $out/bin/funes already exists. preFixup also lets fixupPhase's own
  # `patchelf --shrink-rpath` tidy the rpath we set here.
  # stdenv.cc.libc supplies libm/libc and stdenv.cc.cc supplies libgcc_s:
  # together the complete NEEDED set. Darwin has no ELF interpreter and its
  # install names are already absolute, so this is Linux-only.
  #
  # DO NOT add `runHook preFixup` / `runHook postFixup` to this body. preFixup
  # is a HOOK, and stdenv already runs it via `runHook preFixup` inside
  # fixupPhase; calling it again from inside itself recurses until the stack
  # overflows. That surfaces as `builder failed due to signal 11
  # (Segmentation fault)` at the very top of fixupPhase with NO diagnostic and
  # no output from this body at all — it looks exactly like a segfaulting
  # patchelf, and it is not. This cost five builds to find.
  #
  # Note the contrast with `installPhase` above, which DOES call
  # `runHook preInstall`: a phase may invoke its *pre/post* hooks, because
  # those are differently-named hooks. A hook may not invoke its own name.
  #
  # The interpreter and rpath come from stdenv's explicit attributes, NOT from
  # $NIX_DYNAMIC_LINKER / $NIX_LDFLAGS. In a plain mkDerivation with no
  # buildInputs, $NIX_DYNAMIC_LINKER is EMPTY (it exists only inside the
  # cc-wrapper) and $NIX_LDFLAGS is merely `-rpath $out/lib`. Both were wrong
  # here at the start; the values below are what work, and they are the idiom
  # already used by features/omp/_omp.pkg.nix.
  # The binary is ~216 MiB, which is the honest closure cost of carrying the
  # embedding and rerank stacks: it is a fetch, not a build, but it is a large
  # one.
  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      --force-rpath \
      --set-rpath "${
        lib.makeLibraryPath [
          stdenv.cc.libc
          (lib.getLib stdenv.cc.cc)
        ]
      }" \
      "$out/bin/funes"
  '';

  # The release is built with `strip = symbols` already, so there is nothing
  # for stdenv to strip and a second pass over 216 MiB is pure cost.
  dontStrip = true;

  # Catches a wrong asset, a bad patchelf rewrite, or an interpreter that
  # cannot resolve — all three produce a binary that parses and links but
  # dies on first exec. Upstream's own installer makes the same assertion.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    got=$($out/bin/funes --version)
    if [ "$got" != "funes ${pinnedVersion}" ]; then
      echo "funes: expected 'funes ${pinnedVersion}', got '$got'" >&2
      exit 1
    fi
    runHook postInstallCheck
  '';

  meta = {
    description = "Recall over your past AI agent sessions (prebuilt binary, pinned release)";
    homepage = "https://github.com/huggingface/funes";
    license = lib.licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    mainProgram = "funes";
  };
}
