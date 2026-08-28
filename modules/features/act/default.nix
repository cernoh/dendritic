# act feature: run GitHub Actions workflows locally in containers.
#
# Composes the docker feature (act drives its steps through the Docker
# daemon) and installs the act CLI. Desktop-class hosts import this via
# attrs/desktop; NIXPC's separate `docker` import dedupes to the same module.
#
# The rc file is delivered as an out-of-store symlink into this checkout
# (homeless-dotfiles policy #93, rung 5) — content lives in ./actrc,
# git-tracked and live-editable, instead of inline HM content. act has no
# --config flag; rc lookup is $HOME/.actrc (verified against the installed
# package, issue #96).
{
  self,
  ...
}:
{
  flake.nixosModules.act =
    {
      pkgs,
      config,
      ...
    }:
    {
      imports = [ self.nixosModules.docker ];

      environment.systemPackages = [ pkgs.act ];

      home-manager.users.${config.dendritic.userName} =
        { config, ... }:
        {
          # Out-of-store symlink into this checkout: content lives in
          # ./actrc, git-tracked and live-editable (rung 5, ghostty/niri
          # pattern). act has no --config flag; rc lookup is $HOME/.actrc
          # (verified against the installed package, issue #96).
          home.file.".actrc".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/act/actrc";
        };
    };
}
