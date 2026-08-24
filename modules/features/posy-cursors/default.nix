# Posy cursor themes for ASAHI, ported from
# ~/.config/home-manager-v3/config/cursor (issue #30 survivor).
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.posyCursors ];
#
# The theme directories are exposed out-of-store into this checkout so the
# pointer shapes stay editable without a rebuild. v3 also referenced a
# Posy_Cursor_White_x11 directory that does not exist upstream — not ported.
#
# Dropped alongside this port (same decision, issue #30): stasis (never
# deployed here), kitty configs and quickshell QML bar (superseded by
# ghostty + noctalia, neither binary installed), drifting-antiquity
# themepack (noctalia owns wallpapers), and the dangling driftwm input.
{ ... }: {
  flake.homeManagerModules.posyCursors =
    {
      config,
      ...
    }:
    {
      home.file = {
        ".icons/Posy_Cursor_Black_h".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/posy-cursors/home/.icons/Posy_Cursor_Black_h";
        ".icons/Posy_Cursor_Black_x11".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/posy-cursors/home/.icons/Posy_Cursor_Black_x11";
        ".icons/Posy_Cursor_White_h".source =
          config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/posy-cursors/home/.icons/Posy_Cursor_White_h";
      };
    };
}
