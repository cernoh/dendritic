# Steam client downgrade: pin the client to headcrab's compatible build instead
# of following Steam's own updates.
#
# The flow is headcrab's, mirrored: block updates with steam.cfg, drop the pinned
# client manifest into Steam's package dir, fetch the matching client files, serve
# them from a local override server and let Steam apply them through
# `-overridepackageurl`.
#
# All four remote artifacts are `refs/heads/...` URLs over a mutable branch, so
# they rotate upstream every few weeks and the FOD then fails with a hash
# mismatch — on any `nixos-rebuild`, whether or not the downgrade is ever run.
# Re-pin them together (one stale pin hides the next) after checking the body is
# the real artifact and not a 404 or redirect page, which hashes just as
# cleanly. This hash is ours to bump, unlike Millennium's.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # A single self-contained executable pinned by content hash.
  remoteTool =
    {
      name,
      url,
      hash,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit name;

      src = pkgs.fetchurl {
        inherit url hash;
      };

      dontUnpack = true;
      dontConfigure = true;
      dontBuild = true;

      installPhase = ''
        runHook preInstall
        install -Dm755 "$src" "$out/bin/${name}"
        runHook postInstall
      '';

      meta = {
        description = "nix-crab helper: ${name}";
        platforms = lib.platforms.linux;
      };
    };

  dgsc = remoteTool {
    name = "nix-crab-dgsc";
    url = "https://github.com/Deadboy666/h3adcr-b-modul3s/raw/refs/heads/main/dgsc";
    hash = "sha256-CJUdjpmNl9xKNcuTdsiIuY+l37Pb8D0vyWKZQD/QBCI=";
  };

  dlm = remoteTool {
    name = "nix-crab-dlm";
    url = "https://github.com/Deadboy666/h3adcr-b-modul3s/raw/refs/heads/main/dlm";
    hash = "sha256-ly66uMEsDEfvfTn5geCKMzovEfrmlWqzuTZlORecdxQ=";
  };

  sources = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Deadboy666/h3adcr-b-modul3s/main/sources.txt";
    hash = "sha256-mLncXMJvvgcSEQ/MZ1Gc/rWtzOUallYAx2D/wpmy9Pc=";
  };

  clientManifest = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Deadboy666/SteamTracking/refs/heads/headcrab/ClientManifest/steam_client_ubuntu12";
    hash = "sha256-qHaZw20ochr1ymrecnb1BtIqEfmCl0cWfZaEX8CAr6U=";
  };

  downgrade = pkgs.writeShellScriptBin "nix-crab-downgrade" ''
    set -euo pipefail

    package_dir="$HOME/.steam/steam/package"
    steam_cfg="$HOME/.steam/steam/steam.cfg"

    mkdir -p "$package_dir" "$(dirname "$steam_cfg")"

    # Written once and then left alone: it is the switch that keeps Steam from
    # re-upgrading over the downgrade, and it survives this script by design.
    if [ ! -f "$steam_cfg" ]; then
      cat ${./steam.cfg} >"$steam_cfg"
    fi

    rm -f "$package_dir"/*

    cd "$package_dir"

    echo "Installing the pinned client manifest..."
    cp ${clientManifest} "$package_dir/steam_client_ubuntu12"

    echo "Fetching the pinned client files (nix-crab-dlm)..."
    ${dlm}/bin/nix-crab-dlm --input-file ${sources} --max-concurrent 16

    echo "Serving the override on :1666 (nix-crab-dgsc)..."
    ${dgsc}/bin/nix-crab-dgsc --port 1666 --silent &
    server_pid=$!
    trap 'kill "$server_pid" 2>/dev/null || true' EXIT

    echo "Applying the downgrade through Steam..."
    steam -forcesteamupdate -forcepackagedownload -overridepackageurl http://localhost:1666/ -exitsteam

    echo "Done."
  '';
in
{
  options.programs.nix-crab.downgrade = {
    enable = lib.mkEnableOption "the nix-crab Steam client downgrade tool";

    package = lib.mkOption {
      type = lib.types.package;
      default = downgrade;
      description = "The nix-crab-downgrade wrapper script.";
    };
  };

  config = lib.mkIf config.programs.nix-crab.downgrade.enable {
    environment.systemPackages = [ config.programs.nix-crab.downgrade.package ];
  };
}
