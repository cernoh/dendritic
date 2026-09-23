# wayfinder-dashboard feature: grill history + map switcher for omp grilling
# sessions, served by a Deno container on NIXPC only.
#
# Files in this directory:
#   compose.yaml              source of truth for the container stack
#   _wayfinder-dashboard.nix  compose2nix output (the `_` prefix keeps
#                             import-tree away from it, so this module imports
#                             it explicitly)
#   dashboard-image/          Deno server: server.ts + deno.json + Dockerfile
#
# Import flake.nixosModules.wayfinder-dashboard from hosts/NIXPC/default.nix
# only. ASAHI stays without it: that host is full on storage. The docker
# daemon itself comes from attrs/desktop -> act -> docker, so this module only
# declares the container backend.
#
# This module adds the wiring compose2nix cannot express:
#   - build the dashboard image when the tag is absent or older than the
#     server source
#   - create the data dir on the 2TB ext4 disk before the first start
#   - publish the dashboard on the tailnet with `tailscale serve`
#
# Omp side (separate change): the session registers the map it is asked about
# (POST /api/maps, idempotent), records each grill round (POST
# .../rounds with the questions + formUrl), and records answers back
# (POST .../answers). The dashboard embeds the live grill_form page, so the
# submit still injects into the session.
{
  self,
  ...
}:
{
  flake.nixosModules.wayfinder-dashboard =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      inherit (config.dendritic) userName;
      user = config.users.users.${userName};

      # Grill history and map registry. Same disk as paseo state, same mount
      # that modules/hosts/NIXPC/nixpcConfiguration.nix declares.
      dataDir = "/mnt/2tb-ext4/wayfinder-dashboard";

      imageTag = "wayfinder-dashboard";
      imageContext = ./dashboard-image;

      # Host port from compose.yaml. The container binds loopback only.
      webPort = 8787;
      # Tailnet port for `tailscale serve`, beside paseo (:80) and herdr-web.
      tailnetPort = 8787;

      imageBuild = pkgs.writeShellApplication {
        name = "wayfinder-dashboard-image-build";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          context=${imageContext}
          current="$(docker image inspect \
            --format '{{ index .Config.Labels "wayfinder-dashboard.context" }}' \
            ${imageTag} 2>/dev/null || true)"
          if [ "$current" = "$context" ]; then
            echo "${imageTag} already built from $context"
            exit 0
          fi
          echo "building ${imageTag} from $context"
          docker build --label "wayfinder-dashboard.context=$context" -t ${imageTag} "$context"
        '';
      };

      dataProvision = pkgs.writeShellApplication {
        name = "wayfinder-dashboard-data-dir";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          dir=${dataDir}
          if [ ! -d "$dir/default" ]; then
            install -d -m 0755 -o ${userName} -g ${user.group} "$dir/default"
            echo "created $dir/default" >&2
          fi
        '';
      };

      tailnetServe = pkgs.writeShellApplication {
        name = "wayfinder-dashboard-tailnet-serve";
        runtimeInputs = [
          config.services.tailscale.package
          pkgs.jq
        ];
        text = ''
          target=http://127.0.0.1:${toString webPort}
          if tailscale serve status --json 2>/dev/null \
            | jq -e --arg t "$target" '[.. | objects | .Proxy? // empty] | index($t)' >/dev/null
          then
            echo "serve already maps $target"
            exit 0
          fi
          tailscale serve --bg --yes --https=${toString tailnetPort} "$target"
          tailscale serve status
        '';
      };
    in
    {
      imports = [ ./_wayfinder-dashboard.nix ];

      virtualisation.oci-containers.backend = lib.mkDefault "docker";

      # Sepia M3 tokens for the dashboard page, from the one color source.
      virtualisation.oci-containers.containers.wayfinder-dashboard.environment = {
        M3_PRIMARY = self.scheme.hex.primary;
        M3_ON_PRIMARY = self.scheme.hex.onPrimary;
        M3_PRIMARY_CONTAINER = self.scheme.hex.primaryContainer;
        M3_SURFACE = self.scheme.hex.surface;
        M3_SURFACE_VARIANT = self.scheme.hex.surfaceVariant;
        M3_BASE = self.scheme.hex.base;
        M3_TEXT = self.scheme.hex.text;
        M3_TEXT_DIM = self.scheme.hex.textDim;
        M3_OUTLINE = self.scheme.hex.outline;
        M3_ERROR = self.scheme.hex.error;
        M3_SUCCESS = self.scheme.hex.success;
      };

      systemd.services = {
        wayfinder-dashboard-image = {
          description = "Build the ${imageTag} image when missing or stale";
          after = [ "docker.service" ];
          requires = [ "docker.service" ];
          before = [ "docker-wayfinder-dashboard.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${imageBuild}/bin/wayfinder-dashboard-image-build";
          };
        };

        docker-wayfinder-dashboard = {
          after = [ "wayfinder-dashboard-image.service" ];
          requires = [ "wayfinder-dashboard-image.service" ];
          # The container bind-mounts the data dir, so systemd must mount the
          # data disk first. A missing disk stops the container instead of
          # letting it write history onto the root filesystem.
          unitConfig.RequiresMountsFor = [ dataDir ];
          # Runs as root before `docker run`, so the data dir exists with the
          # right owner when the container first writes history.
          serviceConfig.ExecStartPre = [ "${dataProvision}/bin/wayfinder-dashboard-data-dir" ];
        };

        # tailscaled owns the tailnet listener; the container stays on
        # loopback. Skipped on a host without the tailscale module.
        wayfinder-dashboard-tailnet-serve = lib.mkIf config.services.tailscale.enable {
          description = "Publish the wayfinder dashboard on the tailnet";
          after = [
            "tailscaled.service"
            "docker-wayfinder-dashboard.service"
          ];
          wants = [ "tailscaled.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${tailnetServe}/bin/wayfinder-dashboard-tailnet-serve";
          };
        };
      };
    };
}
