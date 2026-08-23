# Stremio-Kai GPL portable mpv configuration packaged for Linux.
# The upstream repo ships Windows-only Stremio/SVP binaries elsewhere; this
# derivation packages only the platform-neutral `portable_config` (mpv.conf,
# input.conf, scripts, script-opts, webmods) fetched from the pinned upstream
# revision. Users source it as their mpv config dir.
#
# `_` prefix: raw data-package definition — import-tree must not auto-import
# it as a flake-parts module; features/stremio-kai/default.nix callPackages it.
{
  lib,
  stdenv,
  src,
}:
stdenv.mkDerivation {
  pname = "stremio-kai";
  version = "4.8.0"; # upstream tag v4.8.0 (2026-08-05), rev 37e6273

  inherit src;

  # No build step: plain data package. Keep the directory name identical to
  # upstream so `~~/` paths in mpv.conf/scripts resolve as upstream intends.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/stremio-kai
    cp -r portable_config $out/share/stremio-kai/portable_config
    runHook postInstall
  '';

  meta = {
    description = "GPL Stremio-Kai portable mpv configuration, Lua scripts, and webmods for Linux";
    homepage = "https://github.com/allecsc/Stremio-Kai";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
