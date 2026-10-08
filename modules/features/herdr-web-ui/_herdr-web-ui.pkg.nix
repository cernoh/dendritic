# herdr-web-ui package — the browser and phone client for the herdr agent
# multiplexer, built from a pinned release tag with a bun lockfile install.
#
# Upstream ships this as a herdr plugin (`herdr-plugin.toml`) whose build steps
# are `bun install` + `bun run build`, and whose `scripts/plugin.ts start` runs
# the app from the checkout. That needs the network at run time and pins
# nothing, so this feature builds the app instead.
#
# Two derivations, because the install must stay offline and deterministic:
#
#   1. `herdr-web-ui-node-modules` is a fixed-output derivation. It runs
#      `bun install --frozen-lockfile` once against the registry and copies the
#      resulting `node_modules` out. An FOD is the only place Nix lets a
#      network fetch happen, and the recursive hash is the lock on it.
#      `--frozen-lockfile` is what makes the output depend on the committed
#      `bun.lock` and not on whatever the registry serves that day, and it is
#      also what runs `package.json`'s `patchedDependencies` — the one entry,
#      `@xterm/xterm@5.5.0`, carries the composition/IME backport that
#      Vite builds from upstream xterm *source* (see `vite.config.ts`
#      `resolve.alias`). A plain npm dependency set cannot express that patch.
#   2. `herdr-web-ui` copies that `node_modules` in, runs `bun run build`
#      (Vite → `dist/`), and installs the whole tree with a `bun` wrapper.
#      Offline: the network is only touched by derivation 1.
#
# `bun` is BOTH the build tool and the runtime, so it is in `nativeBuildInputs`
# and in the wrapper. `nodejs` is a runtime dependency, not build-time only:
# the terminal attach runs `node pty-host.mjs` as a sidecar, because loading
# `@lydell/node-pty` in bun panics (oven-sh/bun#18546). Without a real `node`
# on PATH the server starts and reports `terminal_attach: false`, and panes
# fall back to read-only mirroring.
#
# `_` prefix: data sibling, imported explicitly by `default.nix`.
{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  nodejs_22,
  makeWrapper,
}:
let
  version = "0.3.52";

  src = fetchFromGitHub {
    owner = "devswha";
    repo = "herdr-web-ui";
    tag = "v${version}";
    hash = "sha256-e0jrgCKDitGI01CM42cZUPqS83jpkZ5LygdMycSjetY=";
  };

  # The one derivation that touches the registry. `recursive` hash mode covers
  # the whole `node_modules` tree, symlinks included — bun's isolated linker
  # makes `node_modules/*` a farm of symlinks into `node_modules/.bun/`, so a
  # flat hash would not describe it.
  nodeModules = stdenv.mkDerivation {
    pname = "herdr-web-ui-node-modules";
    inherit version src;

    nativeBuildInputs = [ bun ];

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-D/N1aOUdPmN6+GEBXvYUt4zwm46wL+VPn7VputSyv2c=";

    # `fixupPhase` rewrites shebangs to absolute store paths, and an FOD output
    # may not reference any store path. Nothing in `node_modules` is executed
    # from here — the consumer copies the tree and the wrapper calls `bun` and
    # `node` by name — so the patching is skipped rather than made idempotent.
    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      # A build sandbox has no writable HOME, and bun writes its cache below it.
      export HOME=$TMPDIR
      export BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache
      bun install --frozen-lockfile --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r node_modules $out/
      runHook postInstall
    '';

    meta = {
      description = "Locked bun dependency tree for herdr-web-ui";
      inherit (src.meta) homepage;
    };
  };
in
stdenv.mkDerivation {
  pname = "herdr-web-ui";
  inherit version src;

  nativeBuildInputs = [
    bun
    makeWrapper
    # `patchShebangs` maps `#!/usr/bin/env node` (which `node_modules/.bin/vite`
    # carries) onto the store node by looking up `node` on PATH.
    nodejs_22
  ];

  buildPhase = ''
    runHook preBuild
    # `dist/` and `node_modules/` are gitignored, so the release tarball ships
    # without either. The install phase copies `dist/` and the runtime reads it
    # from `join(import.meta.dir, "..", "dist")`, so it must exist before the
    # tree is installed.
    cp -r ${nodeModules}/node_modules .
    # The dependency tree is a fixed-output derivation, which may not reference
    # store paths, so its launchers still say `#!/usr/bin/env node` - an
    # interpreter a build sandbox does not have, and `bun run` executes them.
    # The store copy is read-only, so make it writable first; `patchShebangs`
    # cannot rewrite a file it may not open for writing.
    chmod -R u+w node_modules
    patchShebangs node_modules
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # The server resolves `./lib/*`, `../shared/*` and `dist/` against
    # `import.meta.dir`, and `node_modules` resolution walks up from there, so
    # the package tree keeps its shape and only the launcher is generated.
    mkdir -p $out/lib/herdr-web-ui
    cp -r . $out/lib/herdr-web-ui/

    makeWrapper ${lib.getExe bun} $out/bin/herdr-web-ui \
      --add-flags "$out/lib/herdr-web-ui/server/index.ts" \
      --prefix PATH : ${
        lib.makeBinPath [
          # The terminal-attach sidecar (`node pty-host.mjs`) — see the header.
          nodejs_22
        ]
      }

    runHook postInstall
  '';

  # Loading the prebuilt native addon is the check: `bun install` succeeds even
  # when a platform package fails to land, and `pty.node` is the one file whose
  # absence silently downgrades every pane to a mirror. The addon is loaded by
  # node, the same runtime the sidecar uses.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    cd $out/lib/herdr-web-ui
    test -f dist/index.html
    ${lib.getExe nodejs_22} -e '
      const pty = require("@lydell/node-pty");
      if (typeof pty.spawn !== "function") throw new Error("@lydell/node-pty.spawn is missing");
      console.log("node-pty loaded");
    '
    runHook postInstallCheck
  '';

  meta = {
    description = "Browser and phone client for the herdr agent multiplexer";
    homepage = "https://github.com/devswha/herdr-web-ui";
    license = lib.licenses.mit;
    mainProgram = "herdr-web-ui";
    platforms = lib.platforms.linux;
  };
}
