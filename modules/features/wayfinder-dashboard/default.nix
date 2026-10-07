# Wayfinder Relay — a mobile-first queue for open Wayfinder tickets.
#
# The app runs as the desktop user's systemd service because it must use that
# user's authenticated `gh`, the live Herdr socket, and Pi executable. It binds
# loopback; the NixOS half publishes it over tailnet HTTPS. A project registered
# in the app owns one Herdr workspace. Starting a frontier ticket claims it on
# GitHub, opens a tab in that workspace, starts Pi, and submits a one-ticket
# Wayfinder brief.
#
# app/server.ts has no framework or dependency tree: Deno serves one responsive
# page and the JSON API. State lives in ~/.local/state/wayfinder-dashboard.
{
  self,
  moduleWithSystem,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.wayfinder-dashboard = pkgs.writeShellApplication {
        name = "wayfinder-dashboard";
        runtimeInputs = [
          pkgs.deno
          pkgs.coreutils
        ];
        text = ''
          data_root="''${DATA_ROOT:-''${XDG_STATE_HOME:-$HOME/.local/state}/wayfinder-dashboard}"
          mkdir -p "$data_root"
          export DATA_ROOT="$data_root"
          # Deno rejects allow-listed subprocesses when a loader override is
          # inherited (for example from `nix shell`); the service needs none.
          unset LD_LIBRARY_PATH LD_PRELOAD
          exec deno run \
            --allow-net \
            --allow-read \
            --allow-write="$data_root" \
            --allow-run=gh,herdr \
            --allow-env \
            ${./app/server.ts} "$@"
        '';
      };
    };

  flake.homeManagerModules.wayfinder-dashboard = moduleWithSystem (
    { self', ... }:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.wayfinder-dashboard;
    in
    {
      options.services.wayfinder-dashboard = {
        package = lib.mkOption {
          type = lib.types.package;
          default = self'.packages.wayfinder-dashboard;
          defaultText = lib.literalExpression "self'.packages.wayfinder-dashboard";
          description = "The Wayfinder Relay server to run.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 8787;
          description = "Loopback port for Wayfinder Relay.";
        };

        bind = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = "Listen address. Keep this on loopback; starting a ticket controls GitHub, Herdr, and Pi.";
        };
      };

      config = {
        home.packages = [ cfg.package ];

        systemd.user.services.wayfinder-dashboard = {
          Unit = {
            Description = "Wayfinder Relay: mobile ticket queue for Herdr and Pi";
            After = [ "herdr-web.service" ];
          };
          Service = {
            ExecStart = lib.getExe cfg.package;
            Environment = [
              "PORT=${toString cfg.port}"
              "BIND=${cfg.bind}"
              "M3_PRIMARY=${self.scheme.hex.primary}"
              "M3_ON_PRIMARY=${self.scheme.hex.onPrimary}"
              "M3_PRIMARY_CONTAINER=${self.scheme.hex.primaryContainer}"
              "M3_SURFACE=${self.scheme.hex.surface}"
              "M3_SURFACE_VARIANT=${self.scheme.hex.surfaceVariant}"
              "M3_BASE=${self.scheme.hex.base}"
              "M3_TEXT=${self.scheme.hex.text}"
              "M3_TEXT_DIM=${self.scheme.hex.textDim}"
              "M3_OUTLINE=${self.scheme.hex.outline}"
              "M3_ERROR=${self.scheme.hex.error}"
              "M3_SUCCESS=${self.scheme.hex.success}"
              "PATH=${
                lib.makeBinPath (
                  with pkgs;
                  [
                    gh
                    herdr
                    pi-coding-agent
                    git
                    openssh
                    coreutils
                  ]
                )
              }"
            ];
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    }
  );

  flake.nixosModules.wayfinder-dashboard =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.wayfinder-dashboard.tailscaleServe;
      userName = config.dendritic.userName;
      hmServices = config.home-manager.users.${userName}.services;
      relay =
        if hmServices ? wayfinder-dashboard then
          hmServices.wayfinder-dashboard
        else
          throw ''
            services.wayfinder-dashboard.tailscaleServe needs homeManagerModules.wayfinder-dashboard for ${userName}.
          '';
    in
    {
      options.services.wayfinder-dashboard.tailscaleServe = {
        enable = lib.mkEnableOption "publishing Wayfinder Relay on the tailnet";

        httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 18787;
          description = "Tailnet HTTPS port that reaches Wayfinder Relay.";
        };
      };

      config = {
        # Importing this NixOS aspect is the enable switch for both halves. The
        # user service is not part of the all-host Home Manager feature set.
        home-manager.sharedModules = [ self.homeManagerModules.wayfinder-dashboard ];

        assertions = lib.optional cfg.enable {
          assertion = config.services.tailscale.enable;
          message = "services.wayfinder-dashboard.tailscaleServe needs services.tailscale.";
        };

        systemd.services.wayfinder-dashboard-tailscale-serve = lib.mkIf cfg.enable {
          description = "Publish Wayfinder Relay on the tailnet";
          wantedBy = [ "multi-user.target" ];
          wants = [ "tailscaled.service" ];
          after = [ "tailscaled.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe pkgs.tailscale} serve --bg --yes --https=${toString cfg.httpsPort} http://${relay.bind}:${toString relay.port}";
            ExecStop = "${lib.getExe pkgs.tailscale} serve --https=${toString cfg.httpsPort} off";
            TimeoutStartSec = "45s";
            TimeoutStopSec = "10s";
            KillSignal = "SIGKILL";
            Restart = "on-failure";
            RestartSec = 60;
          };
        };
      };
    };
}
