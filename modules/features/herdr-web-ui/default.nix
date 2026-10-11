# herdr-web-ui feature — a second, richer browser/phone UI for herdr.
#
# herdr keeps a persistent pty per pane and exposes them over a JSON socket.
# This app is a Bun server (`bun server/index.ts`) that serves a React client
# from `dist/`, bridges every pane to a WebSocket, and adds what the older
# `herdr-web` bridge does not: a chat view for agent panes, file viewing, web
# push alerts, remote PCs over SSH, and its own Settings UI.
#
# The package is `_herdr-web-ui.pkg.nix`. This module runs it as a systemd user
# service and puts it on PATH, exactly as `features/herdr-web/default.nix` does
# for the other bridge — the two are independent and can run side by side on
# different ports.
#
# Why a service and not upstream's herdr plugin: the plugin manifest
# (`herdr-plugin.toml`) runs `bun install` and `bun run build` inside a checkout
# it manages, and updates itself from git at run time. That needs the network
# and pins nothing. The store copy here is already built, and a user service
# survives a herdr restart.
#
# SECURITY: the app authenticates devices, but a fresh install has no paired
# device and no token. It therefore binds to loopback only. A phone cannot
# reach loopback, so publish it on the tailnet with the `tailscaleServe` option
# of the NixOS module. Tailscale terminates TLS and reports the login, which the
# server compares with this PC's; the user's own devices get in as the user.
# HTTPS is also what unlocks PWA install and web push.
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
# This bridge is client-only: unlike `herdr-web` it never starts the daemon, it
# only connects to `~/.config/herdr/herdr.sock`. A herdr server must already be
# running. On NIXPC `herdr-web.service` is what starts it (that bridge spawns
# `herdr server` when none runs); without either, this server still starts,
# reports herdr unavailable, and recovers once a herdr client attaches.
#
# The service PATH carries every binary the bridge shells out to. `herdr` is
# deliberately not baked into the package: `herdr update` replaces the running
# daemon, and a store copy could then lag the daemon it talks to.
#   - `herdr`  — the socket client this bridge drives (`~/.config/herdr/herdr.sock`).
#   - `node`   — the terminal-attach sidecar (`node pty-host.mjs`). Without it
#                the server still starts, but reports `terminal_attach: false`
#                and every pane is read-only. The package wrapper already adds
#                it; the explicit entry keeps the service working if the
#                wrapper is ever bypassed.
#   - `git`, `ssh`, `ssh-keygen` — the file view (`git ls-files`), remote PCs
#                over SSH, and the generated key pair for a remote PC.
#   - `bash`   — the shell agents the app can start in a pane.
#
# `_herdr-web-ui.pkg.nix` is the derivation; see its header for why the
# dependency install is a fixed-output derivation.
{
  self,
  moduleWithSystem,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.herdr-web-ui = pkgs.callPackage ./_herdr-web-ui.pkg.nix { };
    };

  flake.homeManagerModules.herdr-web-ui = moduleWithSystem (
    { self', ... }:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.herdr-web-ui;
    in
    {
      options.services.herdr-web-ui = {
        package = lib.mkOption {
          type = lib.types.package;
          default = self'.packages.herdr-web-ui;
          defaultText = lib.literalExpression "self'.packages.herdr-web-ui";
          description = "The herdr-web-ui server to run.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 7317;
          description = "Port the server listens on. Point the TLS proxy at this port.";
        };

        bind = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = ''
            Address the server listens on. Keep this on loopback: with no
            paired device and no token, a reachable address is open terminal
            control.
          '';
        };

        authTokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            File holding `HERDR_WEB_TOKEN=<token>` for scripts and proxies.
            Only needed when something other than Tailscale terminates the
            connection. The file is read at start; it is never copied into
            the store, so a secret read from a path outside the store survives
            garbage collection and stays out of the nix store.
          '';
        };
      };

      config = {
        home.packages = [ cfg.package ];

        systemd.user.services.herdr-web-ui = {
          Unit = {
            Description = "herdr-web-ui: browser and phone client for herdr";
            Documentation = [ "https://github.com/devswha/herdr-web-ui" ];
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
                    nodejs_22
                    git
                    openssh
                    bash
                  ]
                )
              }"
            ]
            ++
              lib.optional (cfg.authTokenFile != null)
                "HERDR_WEB_TOKEN=${
                  # `readFile` at evaluation time would put the token in the
                  # store; systemd reads the file instead.
                  toString cfg.authTokenFile
                }";
            Restart = "on-failure";
            RestartSec = 5;
          };

          Install.WantedBy = [ "default.target" ];
        };
      };
    }
  );

  # ---------------------------------------------------------------------------
  # NixOS module — publish the loopback server on the tailnet.
  # ---------------------------------------------------------------------------
  # `tailscale serve` terminates TLS on the tailnet and proxies to the local
  # address, so the phone gets an HTTPS origin and the server keeps its loopback
  # bind. Read the address back from the home-manager service, so the proxy
  # target can not drift from the port the server listens on.
  #
  # That read makes `homeManagerModules.herdr-web-ui` a requirement for the
  # primary user, which is why this module adds it to
  # `home-manager.sharedModules` itself. Nix reports an unknown option when it
  # is absent, so the read is guarded and the message names the module.
  #
  # NIXPC is the only host that imports this aspect. That is a build contract,
  # not just a placement choice: `herdr-web-ui-node-modules` is a fixed-output
  # derivation, and the tree bun resolves for aarch64 is not the tree bun
  # resolves for x86_64 (platform-specific esbuild/oxide/node-pty packages), so
  # the pinned recursive hash only holds on the architecture it was taken on.
  # ASAHI ran the whole stack and failed the build with a hash mismatch until
  # the import was made host-local.
  #
  # The httpsPort follows the home-manager service's port instead of overriding
  # it, because upstream already picked 7317 and nothing here needs a different
  # one; 17317 keeps it clear of the `herdr-web` bridge's 17930, and the two
  # servers are separate programs that must never share a port.
  flake.nixosModules.herdr-web-ui =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.herdr-web-ui;
      httpsPort = cfg.tailscaleServe.httpsPort;

      hmServices = config.home-manager.users.${config.dendritic.userName}.services;

      bridge =
        if hmServices ? herdr-web-ui then
          hmServices.herdr-web-ui
        else
          throw ''
            services.herdr-web-ui.tailscaleServe reads the server address from the home-manager service, but ${config.dendritic.userName} does not import homeManagerModules.herdr-web-ui.
          '';
    in
    {
      options.services.herdr-web-ui.tailscaleServe = {
        enable = lib.mkEnableOption "publishing the herdr-web-ui server on the tailnet";

        httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 17317;
          description = ''
            Tailnet HTTPS port that reaches the server. Distinct from the
            herdr-web bridge's 17930 so both can be published at once.
          '';
        };
      };

      config = {
        # Importing this NixOS aspect is the enable switch for both halves. The
        # user service is not part of the all-host Home Manager feature set
        # (`system/home-manager`), and it must not be: the package's dependency
        # tree is a fixed-output derivation whose recursive hash describes the
        # tree bun resolves for *this* architecture. NIXPC (x86_64-linux) is the
        # only host that imports the module, and it is the host the hash was
        # taken on, so no other host can pull the derivation into its closure.
        home-manager.sharedModules = [ self.homeManagerModules.herdr-web-ui ];

        assertions = lib.optionals cfg.tailscaleServe.enable [
          {
            assertion = config.services.tailscale.enable;
            message = ''
              services.herdr-web-ui.tailscaleServe needs services.tailscale.
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
        systemd.services.herdr-web-ui-tailscale-serve = lib.mkIf cfg.tailscaleServe.enable {
          description = "Publish the herdr-web-ui server on the tailnet";
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
