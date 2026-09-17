# paseo feature: the Paseo daemon and its bundled web UI in a Docker
# container, published to the tailnet by tailscaled.
#
# Files in this directory:
#   compose.yaml    source of truth for the container stack
#   _paseo.nix      compose2nix output (the `_` prefix keeps import-tree away
#                   from it, so this module imports it explicitly)
#   paseo-image/    child image: adds the agent CLIs the daemon spawns
#
# Import flake.nixosModules.paseo from the host preset that runs the daemon
# (NIXPC). The docker daemon itself comes from attrs/desktop -> act -> docker,
# so this module only declares the container backend.
#
# This module adds the wiring compose2nix cannot express:
#   - build the child image when the tag is absent or older than the
#     Dockerfile
#   - wait for the 2TB ext4 disk before the container starts
#   - create the daemon password file outside the store, before the first
#     container start
#   - publish the web UI on the tailnet with `tailscale serve`
#
# Data lives on the 2TB ext4 disk, the same mount that
# modules/hosts/NIXPC/nixpcConfiguration.nix declares as /mnt/2tb-ext4.
{
  self,
  ...
}:
{
  flake.nixosModules.paseo =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    let
      inherit (config.dendritic) userName;
      user = config.users.users.${userName};

      # Container state, worktrees and agent credentials (see compose.yaml).
      dataDir = "/mnt/2tb-ext4/paseo";

      # Paseo hashes this plaintext at startup and never stores it. The
      # deployment passes it as PASEO_PASSWORD, so this file stays the single
      # source for the password: edit it and restart docker-paseo. Delete it
      # and the next start generates a new one.
      passwordEnv = "${user.home}/.config/paseo/paseo.env";

      imageTag = "paseo-with-agents";
      imageContext = ./paseo-image;

      # Host port from compose.yaml. The container binds loopback only.
      webPort = 6767;
      # Tailnet port for `tailscale serve`: port 80 gives http://nixpc/.
      tailnetPort = 80;

      imageBuild = pkgs.writeShellApplication {
        name = "paseo-image-build";
        runtimeInputs = [ pkgs.docker ];
        text = ''
          context=${imageContext}
          current="$(docker image inspect \
            --format '{{ index .Config.Labels "paseo.context" }}' \
            ${imageTag} 2>/dev/null || true)"
          if [ "$current" = "$context" ]; then
            echo "${imageTag} already built from $context"
            exit 0
          fi
          echo "building ${imageTag} from $context"
          docker build --label "paseo.context=$context" -t ${imageTag} "$context"
        '';
      };

      passwordProvision = pkgs.writeShellApplication {
        name = "paseo-password-env";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          env_file=${passwordEnv}
          if [ -f "$env_file" ]; then
            exit 0
          fi
          install -d -m 0700 -o ${userName} -g ${user.group} "$(dirname "$env_file")"
          password="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d '[:space:]')"
          echo "PASEO_PASSWORD=$password" > "$env_file"
          chown ${userName}:${user.group} "$env_file"
          chmod 0600 "$env_file"
          echo "created $env_file. Read it to log in to the web UI." >&2
        '';
      };

      tailnetServe = pkgs.writeShellApplication {
        name = "paseo-tailnet-serve";
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
          tailscale serve --bg --yes --http=${toString tailnetPort} "$target"
          tailscale serve status
        '';
      };
    in
    {
      imports = [ ./_paseo.nix ];

      virtualisation.oci-containers.backend = lib.mkDefault "docker";

      virtualisation.oci-containers.containers.paseo = {
        # Built here; the tag exists in no registry.
        pull = "never";
        environmentFiles = [ passwordEnv ];
      };

      systemd.services = {
        # compose2nix maps a compose `build` section to a service that runs
        # `docker build` on every start. Keep the image outside the generated
        # file instead: the context then comes from the store and the build
        # runs only when the label no longer matches.
        paseo-image = {
          description = "Build the ${imageTag} image when missing or stale";
          after = [ "docker.service" ];
          requires = [ "docker.service" ];
          before = [ "docker-paseo.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${imageBuild}/bin/paseo-image-build";
          };
        };

        docker-paseo = {
          after = [ "paseo-image.service" ];
          requires = [ "paseo-image.service" ];
          # The container bind-mounts both directories, so systemd must mount
          # the data disk first. A missing disk stops the container instead of
          # letting it write a fresh home onto the root filesystem.
          unitConfig.RequiresMountsFor = [
            "${dataDir}/home"
            "${dataDir}/workspace"
          ];
          # Runs as root before `docker run`, so it creates the file the
          # container then reads through --env-file.
          serviceConfig.ExecStartPre = [ "${passwordProvision}/bin/paseo-password-env" ];
        };

        # tailscaled owns the tailnet listener; the container stays on
        # loopback. Skipped on a host without the tailscale module.
        paseo-tailnet-serve = lib.mkIf config.services.tailscale.enable {
          description = "Publish the paseo web UI on the tailnet";
          after = [
            "tailscaled.service"
            "docker-paseo.service"
          ];
          wants = [ "tailscaled.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${tailnetServe}/bin/paseo-tailnet-serve";
          };
        };
      };
    };
}
