# Dux search (dsearch) feature: the indexed filesystem search daemon behind the
# shell's search panel. Home-manager half only.
#
# `inputs.dsearch` publishes `homeModules.dsearch` and nothing else — there is
# no NixOS module, so `programs.dsearch` only exists inside home-manager and a
# NixOS-side definition of it aborts the eval. The upstream module installs the
# package plus the `dsearch.service` user unit (`dsearch serve`) and renders
# `~/.config/dsearch/config.toml` when `programs.dsearch.config` is set.
{ self, inputs, ... }:
{
  flake.homeManagerModules.dsearch = {
    imports = [ inputs.dsearch.homeModules.dsearch ];

    programs.dsearch.enable = true;
  };
}
