# Wayland clipboard tooling for hosts whose clipboard history depends on
# `wl-paste --watch` (Noctalia + cliphist). Only the C `wl-clipboard` ships
# `--watch`; the Rust `wl-clipboard-rs` does not (verified via `wl-paste
# --help`). ASAHI's _noctalia-settings.nix relies on `--watch`, so it uses
# this module. NIXPC gets wl-clipboard-rs instead through the `mango` feature.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.clipboard ];
{ ... }: {
  flake.homeManagerModules.clipboard =
    {
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        wl-clipboard
      ];
    };
}
