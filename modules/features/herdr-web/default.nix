# herdr-web feature — mobile-first web UI for the herdr agent multiplexer.
#
# herdr keeps a persistent pty per pane and exposes them over a JSON socket.
# herdr-web is a Node bridge: it reads the panes you watch and serves them to a
# phone browser, then sends keys and prompts back. An agent can then be watched
# and driven away from the desk.
#
# The package is `_herdr-web.pkg.nix`. This module runs it as a systemd user
# service and puts it on PATH.
#
# Why a service and not upstream's herdr plugin: the plugin manifest
# (`herdr-plugin.toml`) runs `npm install` inside the checkout and starts the
# server from it. That needs the network at run time and pins nothing. The
# store copy here is already complete, and a user service survives a herdr
# restart.
#
# SECURITY: the bridge has no authentication and grants terminal control of
# every pane. It therefore binds to loopback only. A phone cannot reach
# loopback, so publish the bridge on the tailnet with the `tailscaleServe`
# option of the NixOS module. It runs the upstream command:
#
#   tailscale serve --bg --https=17930 http://127.0.0.1:7930
#   # then open https://<machine>.<tailnet>.ts.net:17930
#
# Tailscale terminates TLS and gives the app an HTTPS origin. HTTPS is also
# what unlocks PWA install and background notifications.
#
# The tailnet owner enables Serve once, in a browser. Until then the client
# blocks and prints:
#
#   Serve is not enabled on your tailnet.
#   To enable, visit: https://login.tailscale.com/f/serve?node=<node-id>
#
# The unit gives up after 45 seconds and retries once a minute, so it turns
# active on its own after that step.
#
# Any authenticated reverse proxy works the same way. The option needs
# `homeManagerModules.herdr-web` for `config.dendritic.userName`, because it
# reads the bridge address from that service. The flake's HM wiring imports
# it.
#
# The service PATH carries every binary the bridge shells out to:
#   - `herdr` — spawns `herdr server` when none runs. It also keeps a hidden
#     `herdr` TUI client in a pty and resizes that pty, which is the only way
#     the panes reflow to the phone width. The socket path defaults to
#     `~/.config/herdr/herdr.sock` (`HERDR_SOCKET_PATH` overrides it).
#   - `zoxide` and `find` — the directory picker (lib/dirs.js).
#   - `ss` — the preview port scan (lib/preview.js).
#
# The runtime `herdr` binary is deliberately not baked into the package
# wrapper: `herdr update` replaces the running daemon, and a store copy could
# then lag the daemon it talks to.
#
# The settings UI writes `~/.config/herdr-web/settings.json`. That file is
# application state, so this feature leaves it alone.
{
  moduleWithSystem,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.herdr-web = pkgs.callPackage ./_herdr-web.pkg.nix { };
    };

  flake.homeManagerModules.herdr-web = moduleWithSystem (
    { self', ... }:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.herdr-web;
    in
    {
      options.services.herdr-web = {
        package = lib.mkOption {
          type = lib.types.package;
          default = self'.packages.herdr-web;
          defaultText = lib.literalExpression "self'.packages.herdr-web";
          description = "The herdr-web bridge to run.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 7930;
          description = "Port the bridge listens on. Point the TLS proxy at this port.";
        };

        bind = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = ''
            Address the bridge listens on. Keep this on loopback: the bridge
            has no authentication.
          '';
        };
      };

      config = {
        home.packages = [ cfg.package ];

        systemd.user.services.herdr-web = {
          Unit = {
            Description = "herdr-web bridge: mobile web UI for herdr";
            Documentation = [ "https://github.com/eyalev/herdr-web" ];
          };

          Service = {
            ExecStart = lib.getExe cfg.package;
            Environment = [
              "HERDR_WEB_PORT=${toString cfg.port}"
              "HERDR_WEB_BIND=${cfg.bind}"
              "PATH=${
                lib.makeBinPath (
                  with pkgs;
                  [
                    herdr
                    zoxide
                    findutils
                    iproute2
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

  # ---------------------------------------------------------------------------
  # NixOS module — publish the loopback bridge on the tailnet.
  # ---------------------------------------------------------------------------
  # `tailscale serve` terminates TLS on the tailnet and proxies to the local
  # address, so the phone gets an HTTPS origin and the bridge keeps its
  # loopback bind. Read the address back from the home-manager service: the
  # proxy target can then not drift from the port the bridge listens on.
  #
  # That read makes `homeManagerModules.herdr-web` a requirement for the
  # primary user. Nix reports an unknown option when it is absent, so the read
  # is guarded and the message names the module.
  flake.nixosModules.herdr-web =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.herdr-web;
      httpsPort = cfg.tailscaleServe.httpsPort;

      hmServices = config.home-manager.users.${config.dendritic.userName}.services;

      bridge =
        if hmServices ? herdr-web then
          hmServices.herdr-web
        else
          throw ''
            services.herdr-web.tailscaleServe reads the bridge address from the home-manager service, but ${config.dendritic.userName} does not import homeManagerModules.herdr-web.
          '';
    in
    {
      options.services.herdr-web.tailscaleServe = {
        enable = lib.mkEnableOption "publishing the herdr-web bridge on the tailnet";

        httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 17930;
          description = "Tailnet HTTPS port that reaches the bridge.";
        };
      };

      config = lib.mkIf cfg.tailscaleServe.enable {
        assertions = [
          {
            assertion = config.services.tailscale.enable;
            message = ''
              services.herdr-web.tailscaleServe needs services.tailscale.
            '';
          }
        ];

        # `--bg` writes the mapping into tailscaled and returns, so a oneshot
        # unit fits. `off` removes only this port's mapping.
        #
        # The client blocks when the tailnet has not enabled Serve, and it
        # prints the enable URL while it waits. `Type=oneshot` has no start
        # timeout by default, so bound the wait explicitly. The unit then fails
        # in about 45 seconds, and the restart policy retries it. Once the
        # tailnet owner enables Serve, a retry applies the mapping.
        systemd.services.herdr-web-tailscale-serve = {
          description = "Publish the herdr-web bridge on the tailnet";
          wantedBy = [ "multi-user.target" ];
          wants = [ "tailscaled.service" ];
          after = [ "tailscaled.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${lib.getExe pkgs.tailscale} serve --bg --yes --https=${toString httpsPort} http://${bridge.bind}:${toString bridge.port}";
            ExecStop = "${lib.getExe pkgs.tailscale} serve --https=${toString httpsPort} off";
            # The client ignores SIGTERM while it waits, so follow with SIGKILL.
            TimeoutStartSec = "45s";
            TimeoutStopSec = "10s";
            KillSignal = "SIGKILL";
            # tailscaled is started, not necessarily online, when this runs at
            # boot. Retry until the node can take a serve mapping.
            Restart = "on-failure";
            RestartSec = 60;
          };
        };
      };
    };
}
