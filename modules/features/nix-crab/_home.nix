# The home-manager half of the base stack: SLSsteam's config, the CloudRedirect
# Flatpak app, and the two files CloudRedirect's own prerequisite checks stat.
#
# The Steam injection itself is the NixOS half's job (it owns `programs.steam`);
# this half is what the user session can see.
{
  sls-steam,
  steamnetsock,
  cloudredirect,
  cloudredirect-moon,
  cloudredirect-cli,
  # This repo's own `nix-flatpak` input, not the copy nix-crab pins: importing
  # both would declare `services.flatpak` twice and abort the eval.
  nix-flatpak,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nix-crab;

  helpers = import ./_lib.nix;

  # The injection module may have swapped in slsteam-moon, which this module
  # system cannot see. CloudRedirect only stats the path (it is a prerequisite
  # check, not a load), so the upstream package is the right thing to link.
  slssteam = sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.sls-steam;

  cli = pkgs.runCommandLocal "cloud_redirect_cli" { } ''
    install -Dm755 ${cloudredirect-cli} "$out/bin/cloud_redirect_cli"
  '';

  # Mirrors the hook the NixOS half puts in LD_PRELOAD: the same `_lib` staging
  # over the same input, so this is the identical store path and the app's status
  # row can never disagree with the library Steam actually loads.
  hookSource = if cfg.cloudredirect.moon.enable then cloudredirect-moon else cloudredirect;

  hookFile = helpers.hookStaged pkgs hookSource;
in
{
  imports = [
    # Provides the typed `services.sls-steam.config` option used below.
    sls-steam.homeModules.sls-steam
    nix-flatpak.homeManagerModules.nix-flatpak

    (import ./_status.nix {
      inherit cloudredirect cloudredirect-moon;
    })
  ];

  options.programs.nix-crab.slssteam.manageConfig = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Whether Nix writes ~/.config/SLSsteam/config.yaml. Off by default: tools
      that edit the file (SteaMidra appends its own key block) would otherwise
      lose their changes on every switch. The upstream typed module always
      evaluates a `source`; this switch decides whether it is written.
    '';
  };

  options.programs.nix-crab.cloudredirect.moon.enable = lib.mkEnableOption ''
    the cloudredirect-moon hook for the ~/.local/share/CloudRedirect symlink.
    Set the NixOS option of the same name too — that one is what Steam loads,
    this one is what the app reports'';

  config = {
    # headcrab-equivalent defaults, and only defaults: a value the user sets
    # wins. PlayNotOwnedGames on, DisableCloud off (CloudRedirect needs cloud
    # enabled to have anything to redirect), SafeMode off — it is aimed at Steam
    # Deck gamemode and self-blocks on desktop.
    services.sls-steam.config = {
      PlayNotOwnedGames = lib.mkDefault true;
      DisableCloud = lib.mkDefault false;

      # Keys SLSsteam's config loader reads that the typed module does not
      # declare. Left out, every start notifies "Config loading errors". These
      # are upstream's own defaults from config_default.hpp.
      MaxSchemaTries = lib.mkDefault 10;
      FakeName = lib.mkDefault "";
      DisableUpdates = lib.mkDefault true;
      DumpClientInterfaces = lib.mkDefault false;
      DepotBlacklist = lib.mkDefault [ ];
      ManifestIds = lib.mkDefault { };
      SteamIdOverride = lib.mkDefault { };

      # Upstream's C++ renamed LogLevel to LogLevels (bitwise flags, 0xff = all)
      # and added CDKeys, while its typed module still declares only the old
      # LogLevel enum — so both keys would be missing from the generated file and
      # SLSsteam would report "Missing LogLevels" / "Missing CDKeys" every start.
      # Drop these two once the typed module catches up.
      LogLevels = lib.mkDefault 255;
      CDKeys = lib.mkDefault { };
    };

    xdg.configFile."SLSsteam/config.yaml".enable = cfg.slssteam.manageConfig;

    services.flatpak = {
      enable = true;

      packages = [
        {
          appId = "org.cloudredirect.CloudRedirect";
          origin = "cloudredirect";
        }
      ];

      # The app's SLSsteam row follows ~/.local/share/SLSsteam/SLSsteam.so (see
      # home.file below) into the Nix store, so the sandbox has to see the
      # store: with only filesystems=home, that link dangles inside the Flatpak
      # and the check reads "SLSsteam: Not found".
      overrides.settings."org.cloudredirect.CloudRedirect".Context.filesystems = [ "/nix/store:ro" ];

      # Declared whole, never inherited: upstream's remote is the dead
      # Selectively11 gh-pages branch, and a failing `flatpak remote-add` makes
      # flatpak-managed-install exit 1, which aborts the entire activation with
      # status 4 — on every switch, whether or not the app is present.
      remotes = [
        {
          name = "flathub";
          location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
        }
        {
          name = "cloudredirect";
          location = "https://raw.githubusercontent.com/crghofficial/cloudredirect/gh-pages/cloudredirect.flatpakrepo";
        }
      ];
    };

    home.file = {
      # Never injected globally: it goes in as a per-game launch option, because
      # it rewrites SteamNetworkingSockets memory and must not meet anti-cheat.
      ".config/SLSsteam/tools/netsock/netsock.so".source = steamnetsock;

      # The CloudRedirect app's prerequisite check stats the imperative
      # h3adcr-b layout. Nix keeps SLSsteam in the store, so without this link
      # the app refuses to deploy/update.
      ".local/share/SLSsteam/SLSsteam.so".source = "${slssteam}/SLSsteam.so";

      ".local/share/CloudRedirect/cloud_redirect_lib".source = "${cli}/bin/cloud_redirect_cli";

      # Same for CloudRedirect's own deploy check: it stats this path and
      # reports "failed to deploy" without it, so the link follows the same hook
      # choice as the LD_PRELOAD above — down to the file inside the staged
      # derivation, which is the exact store path LD_PRELOAD names.
      ".local/share/CloudRedirect/cloud_redirect.so".source = "${hookFile}/cloud_redirect.so";
    };

    # `cloud_redirect_cli` on PATH: CloudRedirect's own CLI, and the same build
    # the ~/.local/share link above points at.
    home.packages = [ cli ];
  };
}
