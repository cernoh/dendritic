# Vesktop — Discord client with Vencord built in (upstream HM
# `programs.vesktop`, modules/programs/vesktop/).
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.vesktop ];
#
# Three upstream contracts shape this module:
#
#  - `programs.vesktop` installs NO package of its own: its shared
#    mkVesktopLikeModule runs with `installPackage = false`, and the vesktop
#    module adds `pkgs.vesktop.override { withSystemVencord = … }` itself. So
#    the option that looks like the install switch (`package`) is not one, and
#    a bare `enable = true` is all that puts the binary in `home.packages`.
#  - Vesktop and Vencord both REWRITE their settings files at runtime, and
#    HM's default delivery is a store symlink: the app's save then fails with
#    EACCES and the user change is lost with only a console error. Both trees
#    therefore set `mutableSettings = true`, which turns the declared values
#    into a jq merge into a real user-owned file on activation (declared
#    values win, arrays are replaced, formatting is not preserved). The price
#    is the upstream-documented one: close Vesktop before a switch, or the two
#    writers interleave.
#  - The sepia theme ships as a THEME FILE, not as `vencord.extraQuickCss`.
#    `~/.config/vesktop/settings/quickCss.css` is a file Vencord WRITES when
#    the user saves the in-app QuickCSS editor, so a store symlink there breaks
#    that editor on every save; theme files are only ever read
#    (`VENCORD_THEMES_DIR = DATA_DIR/themes`, Vesktop src/main/constants.ts),
#    so a symlink is the right channel and the user's own QuickCSS stays
#    theirs. `enabledThemes` names the file — Vencord themes are opt-in, and
#    because arrays are replaced by the merge above, themes the user enables in
#    the UI do not survive a switch.
#
# Theming reads `self.scheme` and never a local hex: the splash window colors
# and every Discord CSS variable below come from the palette, so repointing the
# scheme needs no edit in this file. Discord renames its variables between
# releases, so the map names only the long-lived ones; a missing name degrades
# to Discord's own color rather than breaking the file.
#
# No machine facts are involved, so nothing is option-driven. Wayland needs no
# flags here either: `waylandBase` sets NIXOS_OZONE_WL system-wide, and the
# nixpkgs wrapper turns that plus WAYLAND_DISPLAY into
# `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations
# --enable-wayland-ime=true`. Screenshare rides the wlr portal backend from
# `system/portals`, with vesktop's own venmic library for audio.
#
# Accepted wart: Vesktop's own release check (src/main/updater.ts) compares its
# version against GitHub and shows an "outdated" banner whenever nixpkgs lags.
# Its "ignore this version" state lives in Vesktop's app state, not in either
# settings tree, so HM cannot silence it.
{
  self,
  ...
}:
{
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.vesktop =
    {
      lib,
      ...
    }:
    let
      scheme = self.scheme;

      # Discord CSS variables, grouped by what they paint. Every value is a
      # palette role; `crust`/`mantle` read as "darker than base", which is how
      # Discord uses its secondary/tertiary surfaces.
      variables = {
        # --- surfaces -------------------------------------------------------
        "--background-primary" = scheme.hex.base;
        "--background-secondary" = scheme.hex.surface;
        "--background-secondary-alt" = scheme.hex.mantle;
        "--background-tertiary" = scheme.hex.crust;
        "--background-accent" = scheme.hex.surfaceHighlight;
        "--background-floating" = scheme.hex.surface;
        "--background-nested-floating" = scheme.hex.surface;
        "--background-mobile-primary" = scheme.hex.base;
        "--background-mobile-secondary" = scheme.hex.surface;
        "--background-base-lowest" = scheme.hex.crust;
        "--background-base-lower" = scheme.hex.base;
        "--background-base-low" = scheme.hex.surface;
        "--background-surface-high" = scheme.hex.surfaceVariant;
        "--background-surface-higher" = scheme.hex.surfaceHighlight;
        "--background-surface-highest" = scheme.hex.overlay;
        "--chat-background" = scheme.hex.base;
        "--home-background" = scheme.hex.base;
        "--modal-background" = scheme.hex.surface;
        "--modal-footer-background" = scheme.hex.crust;
        "--channeltextarea-background" = scheme.hex.surfaceVariant;
        "--input-background" = scheme.hex.surfaceVariant;

        # --- text -----------------------------------------------------------
        "--text-normal" = scheme.hex.text;
        "--text-muted" = scheme.hex.textMuted;
        "--text-link" = scheme.hex.primary;
        "--text-brand" = scheme.hex.primary;
        "--text-danger" = scheme.hex.error;
        "--text-warning" = scheme.hex.warning;
        "--text-positive" = scheme.hex.success;
        "--header-primary" = scheme.hex.text;
        "--header-secondary" = scheme.hex.textMuted;
        "--channels-default" = scheme.hex.textDim;
        "--interactive-normal" = scheme.hex.textMuted;
        "--interactive-hover" = scheme.hex.text;
        "--interactive-active" = scheme.hex.text;
        "--interactive-muted" = scheme.hex.outline;

        # --- accent ---------------------------------------------------------
        # Discord derives its brand ramp from --brand-500 alone on most
        # surfaces; --brand-experiment (and its `new` alias) is what the
        # buttons actually read.
        "--brand-experiment" = scheme.hex.primary;
        "--brand-experiment-new" = scheme.hex.primary;
        "--brand-500" = scheme.hex.primary;
        "--brand-560" = scheme.hex.primaryContainer;
        "--focus-primary" = scheme.hex.primary;

        # --- state ----------------------------------------------------------
        "--status-danger" = scheme.hex.error;
        "--status-warning" = scheme.hex.warning;
        "--status-positive" = scheme.hex.success;
        "--status-online" = scheme.hex.success;
        "--status-idle" = scheme.hex.warning;
        "--status-dnd" = scheme.hex.error;
        "--status-offline" = scheme.hex.outline;
        "--status-streaming" = scheme.hex.secondary;

        # --- highlights and chrome ------------------------------------------
        "--background-message-hover" = scheme.hex.hover;
        "--mention-background" = scheme.hex.selection;
        "--mention-foreground" = scheme.hex.onSelection;
        "--background-mentioned" = scheme.hex.selection;
        "--background-mentioned-hover" = scheme.hex.hover;
        "--scrollbar-thin-thumb" = scheme.hex.overlay;
        "--scrollbar-thin-track" = scheme.hex.crust;
        "--scrollbar-auto-thumb" = scheme.hex.overlay;
        "--scrollbar-auto-track" = scheme.hex.crust;
      };

      # Vencord appends theme CSS after Discord's own stylesheet. `:root`
      # alone would lose to Discord's `.theme-dark` class selector, hence the
      # class selectors here and `!important` on every declaration.
      sepiaTheme = ''
        /* Sepia — generated by modules/features/vesktop/default.nix from
           modules/features/scheme. Do not edit: the palette is the source of
           truth, and this file is regenerated on every switch. */
        :root,
        .theme-dark,
        .theme-darker,
        .theme-midnight {
        ${lib.concatLines (lib.mapAttrsToList (name: value: "  ${name}: ${value} !important;") variables)}
        }
      '';
    in
    {
      programs.vesktop = {
        enable = true;

        # The app writes both files back; see the header.
        mutableSettings = true;
        vencord.mutableSettings = true;

        settings = {
          discordBranch = "stable";

          # Neither host runs a StatusNotifierItem host (noctalia ships no tray
          # module), so a tray icon would be invisible — and upstream defaults
          # `minimizeToTray` to true, which would then hide a running Vesktop
          # with no way back to it. X closes the app instead.
          tray = false;
          minimizeToTray = false;

          # Splash window in the palette. `splashTheming` is upstream-default
          # true; without the two colors the splash stays Discord blurple.
          splashTheming = true;
          splashBackground = scheme.hex.crust;
          splashColor = scheme.hex.primary;

          # Rich presence for native games and Steam (off upstream): Vesktop
          # runs its own arRPC server on :6463, which Discord's client queries.
          arRPC = true;
        };

        vencord = {
          settings = {
            # nixpkgs pins Vencord; its updater can neither write the store nor
            # be allowed to drift from the Vesktop build it is patched into.
            autoUpdate = false;
            autoUpdateNotification = false;
            enabledThemes = [ "sepia.css" ];
          };

          themes.sepia = sepiaTheme;
        };
      };
    };
}
