# Noctalia desktop shell feature (v5): bars, panels, launcher, lock screen.
#
# Integration per noctalia-docs (getting-started/nixos.mdx):
# - NixOS module installs system-wide and `recommendedServices` enables the
#   services its wifi/bluetooth/power/battery widgets require (NM + BT are
#   already provided by core/network; UPower and a power-profile service come
#   from here).
# - HM module renders `programs.noctalia.settings` into ~/.config/noctalia/.
#
# Settings themselves are PER-HOST values: ASAHI keeps the full set from
# hm-v3's shared config/noctalia.nix (hosts/ASAHI/_noctalia-settings.nix);
# NIXPC carries its compact bar-layout variant inline in nixpcConfiguration.
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
