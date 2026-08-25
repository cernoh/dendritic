# Docker feature: container runtime + compose CLI.
#
# Host-scoped — currently NIXPC only. Import flake.nixosModules.docker
# from the host preset that needs containers.
#
# Why it exists here:
#   - The omp MCP stack (modules/features/omp/home/agent/mcp.json) runs its
#     HTTP servers in containers: scrapling :8000, agentwebsearch :8902,
#     hindsight :8888.
{
  ...
}:
{
  flake.nixosModules.docker =
    {
      pkgs,
      config,
      ...
    }:
    {
      virtualisation.docker.enable = true;

      # Container access for the primary user (merged into the groups set
      # by system/core's nixosModules.user).
      users.users.${config.dendritic.userName}.extraGroups = [ "docker" ];

      environment.systemPackages = [
        pkgs.docker-compose
      ];
    };
}
