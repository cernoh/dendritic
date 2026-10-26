# pi-bolt package — the Pi coding agent compiled ahead of time, fetched as the
# upstream release tarball.
#
# Upstream `opensec-git/Pi-Bolt` publishes one tarball per platform/variant on
# its GitHub releases, each line in the release's `SHA256SUMS` (signed). The
# tarball holds a single ~246 MiB AOT-compiled executable named `pi` plus the
# data it reads from its own install directory (`pi-bolt.txt`, `theme/`,
# `docs/`, `export-html/`, `photon_rs_bg.wasm`, and the X11 native module under
# `native/linux/prebuilds/`). Pi-Bolt resolves those relative to the
# executable's own directory, so the tree has to stay intact.
#
# Why a fetch and not a build: Pi-Bolt's whole point is that the JS is compiled
# to machine code at release time. Building it means reproducing OpenSec's
# compile pipeline (and, for the `-jit` variants, a bundled JIT) — far more than
# this flake should own for a tool that ships a supported binary. Same reasoning
# and shape as `features/funes/_funes.pkg.nix`, and it must stay pure: it lands
# in `environment.systemPackages`, so an activation-time fetch would break the
# pure host eval gates.
#
# --- Why this file does not look like funes' ---------------------------------
#
# Pi-Bolt's executable is a Bun-compiled standalone binary (its crash handler
# announces "Bun Canary v1.4.3"). Bun's launcher maps its OWN file at fixed
# high addresses, so it is not a normal ELF consumer:
#
#   * patchelf --set-interpreter            → fine.
#   * patchelf --set-rpath / --force-rpath  → the process SEGFAULTs (exit 139)
#     at ~0x20f528 before printing anything, rpath value irrelevant. Adding the
#     DT_RPATH/DT_RUNPATH entry rewrites the dynamic section in a way Bun's
#     self-loader cannot survive. Verified four ways: DT_RUNPATH, DT_RPATH,
#     one entry, two entries — all crash; interpreter-only patch runs.
#   * Running the binary through an explicit loader (`ld.so --library-path …
#     ./pi`) also crashes, with SIGBUS at 0x200600000000: /proc/self/exe is then
#     the loader, and the self-map reads a file that is not the program.
#
# So there is no rpath to set, and no loader to poke. What is left is the
# interpreter plus a library search path in the environment, which is exactly
# what NixOS' own `nix-ld` does system-wide: patch PT_INTERP onto the Nix glibc
# loader and prepend that glibc's `lib` to LD_LIBRARY_PATH from a small
# launcher. The launcher is also why `bin/pi-bolt` is a script rather than a
# symlink to `lib/pi-bolt/pi`.
#
# LD_LIBRARY_PATH is inherited by whatever pi-bolt runs (its bash tool and the
# processes those start). It carries one directory — the glibc the binary was
# linked against, whose names (`libc.so.6`, `libm.so.6`, `libpthread.so.0`,
# `libdl.so.2`) collide with nothing else in a Nix store. The X11 native module
# is a normal shared object dlopen'd by path, so IT gets a real rpath, and
# libxcb resolves there and nowhere near the executable.
#
# Variants (see upstream's `install.sh`, `PIBOLT_VARIANT`):
#   x64           — x86-64 with AVX2. Requires AVX2 *and* SSE4.2; a build without
#                   those stops with "Illegal instruction". This is upstream's
#                   own default on an AVX2 CPU, and what both hosts here have.
#   x64-baseline  — x86-64 for any CPU (still needs SSE4.2). Pass
#                   `variant = "x64-baseline"` for a host without AVX2.
#   arm64         — aarch64-linux (ASAHI).
# The `-jit` variants are deliberately not listed: this flake wants the
# no-JIT build (faster startup, smaller binary), and nothing here asks for one.
#
# To bump: read the new release's `SHA256SUMS`, take the sha256 of the
# `pi-bolt-linux-<variant>.tar.xz` line, convert it with
#   nix hash convert --hash-algo sha256 --to sri <hex>
# and replace the hash below. Bump `pinnedVersion` with it — the URL is derived
# from it (tag `bolt-v<pinnedVersion>`).
#
# `_` prefix: raw package definition — import-tree must not auto-import it as a
# flake-parts module; features/pi-bolt/default.nix callPackages it.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  makeWrapper,
  xz,
  libxcb,
  variant ? if stdenv.hostPlatform.isx86_64 then "x64" else "arm64",
}:
let
  pinnedVersion = "1.0.3";

  system = stdenv.hostPlatform.system;

  # SRI hashes, straight from that release's SHA256SUMS.
  hashes = {
    x86_64-linux = {
      x64 = "sha256-HHQUYT82MWI2vYpzIZP7263RrIkygTqM10MZaqdB92k=";
      x64-baseline = "sha256-7lI0yr0nNf5QADtMzAzEZLx/7y0uW9B8fbdAK1X/unQ=";
    };
    aarch64-linux.arm64 = "sha256-vzTWOc9Ma1b1sVZKZOraDIM1kkMbZpQ/N0mGdREWESU=";
  };

  perSystem =
    hashes.${system}
      or (throw "pi-bolt has no Linux release asset for ${system}; upstream publishes x86_64-linux (x64, x64-baseline) and aarch64-linux (arm64) only");

  hash =
    perSystem.${variant}
      or (throw "pi-bolt has no `${variant}` build for ${system}; pick one of: ${lib.concatStringsSep ", " (builtins.attrNames perSystem)}");

  # Tarball name and its single top-level directory, e.g. `pi-bolt-linux-x64`.
  assetName = "pi-bolt-linux-${variant}";

  # `native/linux/prebuilds/<this>/…` — the arch tag inside the tarball.
  prebuildsDir = "linux-${variant}";

  libc = stdenv.cc.libc;
in
stdenv.mkDerivation {
  pname = "pi-bolt";
  version = pinnedVersion;

  src = fetchurl {
    url = "https://github.com/opensec-git/Pi-Bolt/releases/download/bolt-v${pinnedVersion}/${assetName}.tar.xz";
    inherit hash;
  };

  # Unpacked by hand in installPhase: the default unpackPhase would cd into the
  # tarball's top-level directory, and `tar --strip-components=1` into $out is
  # both simpler to read and impossible to get wrong if upstream ever adds a
  # second top-level entry.
  dontUnpack = true;

  nativeBuildInputs = [
    patchelf
    makeWrapper
    xz
  ];

  # stdenv's patchelf hook runs `--shrink-rpath` over every ELF in $out. Hand
  # the two files below a rewrite and it would drop the .node's libxcb rpath
  # (nothing the .node's own NEEDED list needs, but only because ld.so is also
  # told to look for it there) and re-touch `pi`, whose only safe edit is
  # PT_INTERP. Keep the hook off and own both rewrites below.
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/pi-bolt $out/bin
    tar -xJf $src -C $out/lib/pi-bolt --strip-components=1
    runHook postInstall
  '';

  # After installPhase, so the files exist (patchelf in patchPhase would find
  # nothing).
  preFixup = ''
    # Interpreter ONLY — see the header: any rpath entry on `pi` segfaults Bun's
    # self-loader.
    patchelf \
      --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" \
      $out/lib/pi-bolt/pi

    # The X11 native module is an ordinary dlopen'd shared object: no
    # interpreter, and a real rpath is both safe and necessary.
    patchelf \
      --force-rpath \
      --set-rpath "${
        lib.makeLibraryPath [
          libc
          libxcb
        ]
      }" \
      $out/lib/pi-bolt/native/linux/prebuilds/${prebuildsDir}/linux-platform-x11.node

    # `pi-bolt`, never `pi`: features/pi-coding-agent already puts a `pi` on
    # the system PATH, and both read the same ~/.pi/agent, so a second `pi`
    # would make the two runtimes indistinguishable at the prompt.
    makeWrapper $out/lib/pi-bolt/pi $out/bin/pi-bolt \
      --prefix LD_LIBRARY_PATH : ${lib.getLib libc}/lib
  '';

  # Upstream ships the executable already stripped; a second pass over 246 MiB
  # is pure cost.
  dontStrip = true;

  # A wrong asset, a bad interpreter rewrite, or a missing library all yield a
  # binary that parses fine and dies on first exec. Upstream's installer
  # asserts the same thing.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    got=$(HOME=$TMPDIR $out/bin/pi-bolt --version)
    case "$got" in
    "Pi-Bolt ${pinnedVersion}"* | *"(Pi-Bolt ${pinnedVersion}"*) ;;
    *)
      echo "pi-bolt: expected a version line naming Pi-Bolt ${pinnedVersion}, got '$got'" >&2
      exit 1
      ;;
    esac

    # The X11 module is the one ELF that carries an rpath; prove the loader can
    # resolve libxcb from it rather than discovering it at first clipboard use.
    ldd $out/lib/pi-bolt/native/linux/prebuilds/${prebuildsDir}/linux-platform-x11.node \
      | grep -q libxcb \
      || {
        echo "pi-bolt: the X11 native module cannot resolve libxcb" >&2
        exit 1
      }
    runHook postInstallCheck
  '';

  meta = {
    description = "The Pi coding agent compiled ahead of time to native code (prebuilt binary, pinned release)";
    homepage = "https://github.com/opensec-git/Pi-Bolt";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "pi-bolt";
  };
}
