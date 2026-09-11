# Noctalia desktop shell feature (v5): bars, panels, launcher, lock screen.
#
# Integration per noctalia-docs (getting-started/nixos.mdx):
# - NixOS module installs system-wide and `recommendedServices` enables the
#   services its wifi/bluetooth/power/battery widgets require (NM + BT are
#   already provided by core/network; UPower and a power-profile service come
#   from here).
# - HM module renders `programs.noctalia.settings` into ~/.config/noctalia/.
#
# Settings themselves are PER-HOST values, each in a `_noctalia-settings.nix`
# beside its host config and imported by that host from its HM submodule:
# hosts/ASAHI/_noctalia-settings.nix (the full set from hm-v3) and
# hosts/NIXPC/_noctalia-settings.nix (a verbatim translation of this host's
# exported config.toml, so a rebuild keeps the tuned live shell).
#
# The cernoh/terminal plugin (panel/bar widget driving $TERMINAL) is symlinked
# out-of-store; hosts that want it list it in plugins.enabled.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.noctalia =
    {
      lib,
      ...
    }:
    {
      imports = [ inputs.noctalia.nixosModules.default ];

      programs.noctalia = {
        enable = true;
        recommendedServices.enable = true;
      };
    };

  flake.homeManagerModules.noctalia =
    {
      config,
      ...
    }:
    {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        enable = true;
        systemd.enable = true;
      };

      # Plugin runtime data must be writable/live, hence out-of-store.
      home.file.".local/share/noctalia/plugins/terminal".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/noctalia/plugins/terminal";
    };
}
