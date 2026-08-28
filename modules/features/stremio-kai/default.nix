# Stremio-Kai mpv configuration feature for NIXPC (issue #27).
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.stremioKai ];
#
# The package is plain data (upstream's portable_config). mpv cannot read a
# read-only store path as its config dir — its Lua scripts persist settings
# in place (~~/scripts/.../track_preferences.json) and store files are 0444.
#
# Homeless config (issue #99, policy #93): the tree is NO LONGER copied into
# the user's real ~/.config/mpv on activation — that silently clobbered
# personal mpv settings and created home-owned state from the flake. Instead
# a `stremio-mpv` wrapper scopes mpv via MPV_HOME to
# ~/.local/share/stremio-kai-mpv, materializing the tree on first run (and
# re-syncing when the pinned package changes) and keeping it writable for
# track_preferences.json persistence. Point Stremio's player at the wrapper:
# Settings → Advanced → player → custom path `stremio-mpv`.
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

      # PATH-visible wrapper: mpv launched for Stremio reads the scoped
      # tree, the user's real ~/.config/mpv stays untouched. First run (or
      # package change, stamped by store path) materializes the tree; the
      # dir is home-owned and writable so the Lua scripts' settings persist.
      stremioMpv = pkgs.writeShellScriptBin "stremio-mpv" ''
        set -e
        dir="$HOME/.local/share/stremio-kai-mpv"
        expected="${stremio-kai}"
        stamp="$dir/.stremio-kai-rev"
        if [ "$(cat "$stamp" 2>/dev/null || true)" != "$expected" ]; then
          mkdir -p "$dir"
          cp -r "${stremio-kai}/share/stremio-kai/portable_config/." "$dir/"
          chmod -R u+w "$dir"
          printf '%s\n' "$expected" > "$stamp"
        fi
        exec env MPV_HOME="$dir" ${pkgs.mpv}/bin/mpv "$@"
      '';
    in
    {
      home.packages = [
        stremio-kai
        stremioMpv
      ];
    };
}
