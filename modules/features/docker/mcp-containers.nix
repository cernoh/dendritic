# Declarative MCP container provisioning for NIXPC (issue #34), replacing
# v3's home.activation.startDockerContainers with NixOS-native
# virtualisation.oci-containers units so systemd owns restart policy and
# boot ordering.
#
# Wire from the NIXPC host preset: import flake.nixosModules.mcpContainers.
#
# Container contract (must keep matching omp's mcp.json ports):
#   scrapling-mcp        127.0.0.1:8000  pyd4vinci/scrapling, mcp --http
#   agentwebsearch-mcp   127.0.0.1:8902  built from the in-repo skill dir
#   hindsight-api        host network    ghcr.io/vectorize-io/hindsight-api:0.8.4
#   hindsight-control-plane host network same tag
#
# Invariants carried over from v3:
#   - The Hindsight LLM key lives ONLY in the primary user's
#     ~/.config/hindsight/.env, never in the store: the api unit gets it via
#     EnvironmentFile and a pre-start check hard-fails when the file is
#     absent (v3 skipped provisioning then; a red unit is the honest
#     declarative equivalent).
#   - agentwebsearch-mcp is built locally from the omp feature's skill dir;
#     a oneshot service builds the image only when missing and the container
#     unit requires+orders after it with pull = "never".
{ ... }:
{
  flake.nixosModules.mcpContainers =
    {
      pkgs,
      config,
      ...
    }:
    let
      # The env file belongs to the host's primary user, not to any fixed
      # login name (issue #61): derive it from dendritic.userName so importing
      # this module on a host with a different primary user keeps pointing at
      # a real path.
      hindsightEnv = "${config.users.users.${config.dendritic.userName}.home}/.config/hindsight/.env";
    in
    {
      virtualisation.oci-containers = {
        backend = "docker";
        containers = {
          scrapling-mcp = {
            image = "pyd4vinci/scrapling";
            autoStart = true;
            cmd = [
              "mcp"
              "--http"
              "--host"
              "0.0.0.0"
              "--port"
              "8000"
            ];
            ports = [ "127.0.0.1:8000:8000" ];
            volumes = [ "scrapling-playwright-cache:/root/.cache/ms-playwright" ];
          };

          agentwebsearch-mcp = {
            image = "agentwebsearch-mcp";
            autoStart = true;
            # Built locally by agentwebsearch-image.service below; never pull.
            pull = "never";
            ports = [ "127.0.0.1:8902:8902" ];
          };

          hindsight-api = {
            image = "ghcr.io/vectorize-io/hindsight-api:0.8.4";
            autoStart = true;
            extraOptions = [ "--network=host" ];
            environmentFiles = [ hindsightEnv ];
            volumes = [ "hindsight-data:/home/hindsight/.pg0" ];
          };

          hindsight-control-plane = {
            image = "ghcr.io/vectorize-io/hindsight-control-plane:0.8.4";
            autoStart = true;
            extraOptions = [ "--network=host" ];
          };
        };
      };

      systemd.services = {
        # One-shot: populate scrapling's Playwright browser cache inside the
        # container (v3 did the same docker exec right after run). Tolerated
        # failure, exactly like v3's `>/dev/null 2>&1` — the MCP server still
        # answers and the next boot retries.
        scrapling-playwright-install = {
          description = "Install Chromium into the scrapling-mcp container";
          after = [ "docker-scrapling-mcp.service" ];
          requires = [ "docker-scrapling-mcp.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            # No exec: the shell must survive to swallow a failed install.
            ${pkgs.docker}/bin/docker exec scrapling-mcp \
              /app/.venv/bin/python -m playwright install --with-deps chromium \
              >/dev/null 2>&1 || true
          '';
        };

        # Build agentwebsearch-mcp from the repo-internal skill dir (Dockerfile +
        # docker-entrypoint.sh) only when the tag is absent — keeps v3's
        # build-if-missing semantics without shelling out of HM activation.
        agentwebsearch-image = {
          description = "Build the agentwebsearch-mcp image if missing";
          after = [ "docker.service" ];
          requires = [ "docker.service" ];
          before = [ "docker-agentwebsearch-mcp.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            if ! ${pkgs.docker}/bin/docker image inspect agentwebsearch-mcp >/dev/null 2>&1; then
              ${pkgs.docker}/bin/docker build -t agentwebsearch-mcp ${./../omp/home/agent/managed-skills/agentwebsearch-mcp}
            fi
          '';
        };

        # Order the generated oci-containers units behind their prerequisites.
        docker-agentwebsearch-mcp = {
          after = [ "agentwebsearch-image.service" ];
          requires = [ "agentwebsearch-image.service" ];
        };
        docker-hindsight-api.serviceConfig.ExecStartPre =
          let
            envCheck = pkgs.writeShellApplication {
              name = "hindsight-env-check";
              text = ''
                if [ ! -f ${hindsightEnv} ]; then
                  echo "hindsight-api: ${hindsightEnv} missing — refusing to start (LLM key must come from this file)" >&2
                  exit 1
                fi
              '';
            };
          in
          [
            "${envCheck}/bin/hindsight-env-check"
          ];
      };
    };
}
