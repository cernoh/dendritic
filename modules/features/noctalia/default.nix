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
# The cernoh/terminal plugin (panel/bar widget) is symlinked out-of-store;
# hosts that want it list it in plugins.enabled. The plugin itself runs in a
# Luau sandbox with no foreign function interface, so it cannot link a C
# library. `ghostty-term` is the helper that bridges the two: it owns the
# pseudo-terminal and a libghostty-vt terminal, and reports the screen to the
# plugin as JSON frames. The helper is a separate derivation rather than part
# of this module because a plugin directory holds only Luau and TOML.
{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
  # Built from the flake's own nixpkgs; libghostty-vt is a standalone package
  # there, separate from pkgs.ghostty, which ships only the sequence parsers
  # under the same soname. libghostty-vt has no x86_64-darwin build, so the
  # helper is offered only where the library is available.
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = lib.optionalAttrs (lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.libghostty-vt) {
        ghostty-term = pkgs.callPackage ./_ghostty-term.pkg.nix { };
      };
    };

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

  flake.homeManagerModules.noctalia = moduleWithSystem (
    { self', ... }:
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

      # The terminal plugin drives this helper, so it must be on PATH for the
      # user session whether or not the plugin is enabled for this host.
      home.packages = [ self'.packages.ghostty-term ];

      # Plugin runtime data must be writable/live, hence out-of-store.
      home.file.".local/share/noctalia/plugins/terminal".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/noctalia/plugins/terminal";
    }
  );
}
