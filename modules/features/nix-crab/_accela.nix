# ACCELA: the depot-downloader GUI from the Enter The Wired bundle, configured to
# hand its games to SLSsteam instead of managing them itself.
{ accela }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # deps.tar.gz layout is fixed by the bundle's own installer.
  dist = pkgs.runCommandLocal "accela-dist" { } ''
    install -d "$out"
    tar -xzf ${accela} --strip-components=1 -C "$out" bin/ACCELA.AppImage bin/accela.png
    chmod +x "$out/ACCELA.AppImage"
  '';

  # appimage-run also supplies the FHS loader the bundled DepotDownloaderMod
  # needs. zstd is not in that rootfs and the bundled PyQt6 links it, so without
  # the override it dies on `import PyQt6.QtGui` — eval and build pass either
  # way, only launching catches it.
  appimageRun = pkgs.appimage-run.override {
    extraPkgs = p: [ p.zstd ];
  };

  launcher = pkgs.writeShellScriptBin "accela" ''
    exec ${lib.getExe appimageRun} ${dist}/ACCELA.AppImage "$@"
  '';

  desktopItem = pkgs.makeDesktopItem {
    name = "accela";
    desktopName = "ACCELA";
    comment = "ＧｏＤ_Ｉｓ_ｉＮ_ｔＨｅ_ＷｉＲｅＤ";
    exec = "${launcher}/bin/accela %u";
    icon = "accela";
    categories = [ "Utility" ];
    # Declared, not registered as the default handler: that would mean owning
    # ~/.config/mimeapps.list through xdg.mimeApps, and every other default with
    # it.
    mimeTypes = [ "x-scheme-handler/accela" ];
    startupNotify = false;
  };

  # The [General] keys the bundle's own `accela` script forces — what makes
  # ACCELA defer to SLSsteam instead of managing game libraries itself.
  seedConfig = pkgs.writeText "ACCELA.conf" ''
    [General]
    auto_skip_single_choice=true
    library_mode=true
    max_downloads=16
    sls_config_management=true
    slssteam_mode=true
    use_steamless=true
  '';
in
{
  options.programs.nix-crab.accela.enable =
    lib.mkEnableOption "ACCELA (Steam depot downloader, Enter The Wired)";

  config = lib.mkIf config.programs.nix-crab.accela.enable {
    home.packages = [ launcher ];

    home.file.".local/share/icons/hicolor/256x256/apps/accela.png".source = "${dist}/accela.png";

    # Not xdg.desktopEntries: XDG_DATA_HOME is searched before the profile, so
    # the entry the bundle's installer writes would shadow ours.
    home.file.".local/share/applications/accela.desktop" = {
      source = "${desktopItem}/share/applications/accela.desktop";
      force = true;
    };

    # Seeded, never managed: QSettings rewrites this file, so a store symlink
    # would break it on the first write. Same reason slssteam.manageConfig
    # defaults to off. The bundle's own script merges its keys into an existing
    # [General] section instead, which is the behaviour lost here on purpose —
    # a file this flake does not own is a file it must not rewrite.
    home.activation.accelaSeedConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      accela_config="${config.xdg.configHome}/Tachibana Labs/ACCELA.conf"
      if [ ! -e "$accela_config" ]; then
        run mkdir -p "$(dirname "$accela_config")"
        run install -m644 ${seedConfig} "$accela_config"
      fi
    '';
  };
}
