# act feature: run GitHub Actions workflows locally in containers.
#
# Composes the docker feature (act drives its steps through the Docker
# daemon) and installs the act CLI. Desktop-class hosts import this via
# attrs/desktop; NIXPC's separate `docker` import dedupes to the same module.
{
  self,
  ...
}:
{
  flake.nixosModules.act =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.nixosModules.docker ];

      environment.systemPackages = [ pkgs.act ];

      # Default runner image so a bare `act push`/`act pull_request` runs
      # non-interactively instead of hanging on the image prompt.
      # Requires the homeManager glue (co-imported by attrs/desktop);
      # per-run overrides still work via -P/--container-architecture.
      home-manager.users.davr.home.file.".actrc".text = ''
        -P ubuntu-latest=catthehacker/ubuntu:act-latest
      '';
    };
}
