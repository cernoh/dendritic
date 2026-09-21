# Retrosmart cursor feature — the `mac-ish` style of the retrosmart-cursor
# fork, recolored with the flake palette.
#
# The input is a plain source tree (flake = false); `_retrosmart-cursor.pkg.nix`
# runs the upstream pipeline for the single scheme this flake wants.
#
# The upstream mac-ish schemes all map `outline` to their palette foreground
# and `fill` to its background (classic is white on black). This feature does
# the same with the sepia palette: the pointer is warm cream on brown instead
# of white on black.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.retrosmartCursor ];
#
# `home.pointerCursor` covers the parts that read the home directory: it puts
# the theme in the home profile and in ~/.icons, sets the GTK cursor theme,
# and exports XCURSOR_THEME/XCURSOR_SIZE for login shells. The compositor is a
# second channel, because a greeter-spawned session takes its environment from
# its own config: the mango feature (NIXPC) and the niri config (ASAHI) both
# read the name and size from `self.retrosmartCursor`.
{
  self,
  inputs,
  lib,
  moduleWithSystem,
  ...
}:
let
  # Upstream tag of the pinned input; keep in step with flake.nix.
  version = "2.0.1";

  # Drives both the theme directory name and the scheme entry that the
  # upstream build reads.
  schemeId = "mac-ish-sepia";

  cursor = {
    name = "retrosmart-xcursor-${schemeId}";
    # The size mango already asks for on NIXPC.
    size = 24;
  };
in
{
  options.flake.retrosmartCursor = lib.mkOption {
    type = lib.types.raw;
    description = "Retrosmart cursor theme name and pointer size, read by the compositor features.";
  };

  config = {
    flake = {
      retrosmartCursor = cursor;

      homeManagerModules.retrosmartCursor = moduleWithSystem (
        { self', ... }:
        {
          home.pointerCursor = {
            enable = true;
            package = self'.packages.retrosmart-cursor;
            inherit (cursor) name size;
            gtk.enable = true;
          };
        }
      );
    };

    perSystem =
      { pkgs, ... }:
      {
        packages.retrosmart-cursor = pkgs.callPackage ./_retrosmart-cursor.pkg.nix {
          src = inputs.retrosmart-cursor;
          inherit schemeId version;

          displayName = "SEPIA (Mac-ish)";
          outline = self.scheme.hex.text;
          fill = self.scheme.hex.base;
        };
      };
  };
}
