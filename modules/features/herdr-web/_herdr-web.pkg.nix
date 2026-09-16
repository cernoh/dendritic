# herdr-web package — the mobile-first web bridge for the herdr agent
# multiplexer, built from a pinned source rev with a locked node dependency set.
#
# Upstream also ships this as a herdr plugin (`herdr-plugin.toml`), but that
# manifest runs `npm install` inside the checkout and starts the server from
# it. That needs the network at run time and pins nothing, so this feature
# builds the bridge instead: `fetchFromGitHub` for the source and
# `buildNpmPackage` with `npmDepsHash` for `express`, `ws`, and `node-pty`.
#
# `node-pty` is an *optional* dependency, and it stays on. The bridge keeps a
# hidden `herdr` TUI client in a pty and resizes that pty (lib/size-driver.js),
# which is the only way the JSON API can resize the headless runtime. Without
# it every agent stays at herdr's 80x24 default instead of reflowing to the
# phone width.
#
# The runtime `herdr` binary is deliberately NOT baked into the wrapper: herdr
# updates itself (`herdr update`) and a store copy could then be older than the
# running daemon. Callers put herdr on PATH instead — see `default.nix`.
#
# `_` prefix: data sibling, imported explicitly by `default.nix`.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
  python3,
}:
buildNpmPackage (finalAttrs: {
  pname = "herdr-web";
  version = "0.1.0-unstable-2026-07-29";

  src = fetchFromGitHub {
    owner = "eyalev";
    repo = "herdr-web";
    rev = "a587fd36ca8b02d56672f2c12b3f81189fe9dca2";
    hash = "sha256-FhHpP9Q98G2LZA/pq/DCONn5uoxnRc5Pl94/Sxl4N88=";
  };

  npmDepsHash = "sha256-cHXN1rjkYPi/ar/1IXSK/fLcHKaf+K14zGN+Eftifok=";

  # node-gyp (for the node-pty addon) needs python3. The store node headers
  # come from buildNpmPackage itself: its npmConfigHook exports
  # `npm_config_nodedir`, so `npm rebuild` compiles offline.
  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  # Upstream has no `build` script; `npmPackages` still compiles the node-pty
  # addon, because buildNpmPackage runs `npm ci` and then `npm rebuild` inside
  # its configure phase.
  dontNpmBuild = true;

  # Upstream's package.json has no `bin` entry, so the default install layout
  # (`$out/lib/node_modules/herdr-web`) gets no launcher. Add one. `server.js`
  # resolves `./lib/*` and `public/` against `__dirname`, so it must keep
  # running from inside the package tree.
  postInstall = ''
    makeWrapper ${lib.getExe nodejs} $out/bin/herdr-web \
      --add-flags $out/lib/node_modules/herdr-web/server.js
  '';

  # The optional native addon is the one part of the dependency set that a
  # lockfile cannot guarantee: `npm ci` keeps going when it fails to compile.
  # Loading it is the check. Starting the server is not — startup spawns
  # `herdr`, which no build sandbox has.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    cd $out/lib/node_modules/herdr-web
    ${lib.getExe nodejs} -e '
      const pty = require("node-pty");
      if (typeof pty.spawn !== "function") throw new Error("node-pty.spawn is missing");
      console.log("node-pty loaded");
    '

    runHook postInstallCheck
  '';

  passthru.herdrWebNodejs = nodejs;

  meta = {
    description = "Mobile-first web UI for the herdr agent multiplexer";
    homepage = "https://github.com/eyalev/herdr-web";
    license = lib.licenses.mit;
    mainProgram = "herdr-web";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
