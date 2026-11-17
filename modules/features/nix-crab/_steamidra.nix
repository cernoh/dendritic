# SteaMidra (SFF): the account/token/manifest GUI, as a .NET 9 AppImage.
#
# The version comes from the `steamidra` input (GitHub's tag list), but the
# ~520 MiB AppImage is NOT fetched by Nix: SFF publishes no versionless asset
# URL, so a Nix fetch would need a hand-bumped SRI hash for every release. The
# launcher downloads exactly the locked version on first run instead — which is
# also the only place it can live, because sff/core/utils.py writes settings.bin
# next to the running binary and the store is read-only.
{ steamidra }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  version = lib.removePrefix "v" (builtins.head (builtins.fromJSON (builtins.readFile steamidra)))
  .name;

  # Absolute, not $HOME: this also ends up in the desktop entry's Icon=, which is
  # not shell-expanded.
  dataDir = "${config.home.homeDirectory}/.local/share/SteaMidra";

  launcher = pkgs.writeShellScriptBin "steamidra" ''
    set -euo pipefail

    app="${dataDir}/SteaMidra.AppImage"

    if [ "$(cat "${dataDir}/.version" 2>/dev/null || true)" != "${version}" ]; then
      ${lib.getExe pkgs.libnotify} -a SteaMidra \
        "Downloading SteaMidra ${version}" "About 520 MiB, this takes a while." || true

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT

      ${lib.getExe pkgs.curl} -fL --progress-bar -o "$tmp/sff.zip" \
        "https://github.com/Midrags/SFF/releases/download/v${version}/SteaMidra-${version}-linux.zip"
      ${lib.getExe pkgs.unzip} -qo "$tmp/sff.zip" "SteaMidra*.AppImage" "*.png" -d "$tmp"

      mkdir -p "${dataDir}"
      mv "$tmp"/SteaMidra*.AppImage "$app"
      chmod +x "$app"
      mv "$tmp"/*.png "${dataDir}/steamidra.png"
      echo "${version}" >"${dataDir}/.version"

      ${lib.getExe pkgs.libnotify} -a SteaMidra "SteaMidra ${version} is ready" || true
    fi

    export APPIMAGE="$app"
    # QtWebEngine's bundled sandbox cannot work inside an AppImage on NixOS.
    export QTWEBENGINE_DISABLE_SANDBOX=1

    exec ${lib.getExe pkgs.appimage-run} "$app" "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "steamidra";
    desktopName = "SteaMidra";
    comment = "Steam game setup and manifest tool";
    exec = "${launcher}/bin/steamidra";
    # Unpacked on first run, so it does not exist until then.
    icon = "${dataDir}/steamidra.png";
    categories = [ "Utility" ];
    startupNotify = false;
  };
in
{
  options.programs.nix-crab.steamidra.enable =
    lib.mkEnableOption "SteaMidra (SFF account and manifest manager)";

  config = lib.mkIf config.programs.nix-crab.steamidra.enable {
    home.packages = [
      pkgs.dotnetCorePackages.runtime_9_0
      launcher
    ];

    # Not xdg.desktopEntries: that lands in the profile, and SteaMidra writes its
    # own ~/.local/share/applications/steamidra.desktop on startup with an Exec
    # pointing at the raw AppImage, which cannot run on NixOS. XDG_DATA_HOME is
    # searched before the profile, so that entry would shadow ours; own the path
    # and force it back on every switch.
    home.file.".local/share/applications/steamidra.desktop" = {
      source = "${desktopItem}/share/applications/steamidra.desktop";
      force = true;
    };
  };
}
