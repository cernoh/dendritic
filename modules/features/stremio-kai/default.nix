# Stremio-Kai mpv configuration feature for NIXPC (issue #27).
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.stremioKai ];
#
# The package is plain data (upstream's portable_config). mpv cannot read a
# read-only store path as its config dir — its Lua scripts persist settings
# in place (~~/scripts/.../track_preferences.json) and store files are 0444 —
# so the activation copies the tree into writable ~/.config/mpv and grants
# u+w, exactly like v3's installStremioKaiConfig.
#
# mpv itself ships from the nixpcDesktop feature (#25).
{ inputs, ... }: {
  flake.homeManagerModules.stremioKai =
    {
      config,
      pkgs,
      ...
    }:
    let
      stremio-kai = pkgs.callPackage ./_stremio-kai.pkg.nix { src = inputs.stremio-kai; };
    in
    {
      home.packages = [ stremio-kai ];

      home.activation.installStremioKaiConfig = config.lib.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.config/mpv"
        cp -r "${stremio-kai}/share/stremio-kai/portable_config/." "$HOME/.config/mpv/"
        chmod -R u+w "$HOME/.config/mpv"
      '';
    };
}
