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
# every pane. It therefore binds to loopback only. Front it with a proxy that
# terminates TLS before a phone can reach it:
#
#   tailscale serve --bg --https=17930 http://127.0.0.1:7930
#   # then open https://<machine>.<tailnet>.ts.net:17930
#
# HTTPS is also what unlocks PWA install and background notifications.
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
}
