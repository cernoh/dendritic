# Dux shell (DMS): bar, panels, launcher, lock screen.
#
# Both halves import the matching upstream module from `inputs.dms`
# (dux-shell) and then enable it. The option upstream publishes is
# `programs.dank-material-shell`; the retired `programs.dms-shell` no longer
# exists anywhere, and defining it aborts the whole rebuild with
# ``The option `home-manager.users.<user>.programs.dms-shell' does not exist``.
#
# Split of duties — upstream defines the `dms.service` unit in BOTH halves, so
# `systemd.enable` is set on exactly one:
# - NixOS half: the system services the widgets need (UPower,
#   accounts-daemon, geoclue2, power-profiles-daemon, polkit) and the
#   system-wide packages. `systemd.enable` stays at its default (off) here.
# - HM half: the user unit itself, bound to the compositor's
#   `wayland.systemd.target`.
#
# `shared` is the feature set both halves declare. It is one attrset on
# purpose: the shell's behaviour must not drift between NixPC and ASAHI, and
# both hosts reach it through `features/dux/default.nix` alone. Every flag in
# it is also upstream's default — they are stated so the live set is readable
# here instead of being inferred from dux-shell's option defaults.
#
# What each flag actually costs, because "enable" here means "add a
# dependency", not "turn a feature on":
# - `enableDynamicTheming` puts `matugen` on PATH for the shell's
#   wallpaper-derived M3 theming (DMS's `matugenTemplate*` targets then write
#   `~/.config/gtk-{3,4}.0/dank-colors.css`, `~/.config/mango/dms/colors.conf`,
#   `~/.config/ghostty/themes/dankcolors`, `~/.config/qt6ct/colors/matugen.conf`
#   and friends — include files, never the app's own config).
# - `enableVPN` → `glib`, `networkmanager`; `enableAudioWavelength` → `cava`;
#   `enableCalendarEvents` → `khal`; `enableSystemMonitoring` → nothing, it is
#   the widgets/keybinds switch.
# `settings`, `clipboardSettings` and `session` are deliberately NOT declared:
# upstream renders each of them as a store symlink under `~/.config/dms/`, and
# the shell rewrites those files from its own UI. Declaring them would freeze
# the live 14 KB `settings.json` (bar layout, widgets) at build time.
#
# No `package` override: upstream builds dms-shell from the *consumer's* pkgs
# (`mkModuleWithDmsPkgs`), so the shell and the quickshell it runs cost one
# nixpkgs eval. `inputs.dms.packages.<system>.default` would instead build
# against dux-shell's own locked nixpkgs — a second Qt tree, for an upstream
# that has no binary cache to substitute from.
{ self, inputs, ... }:
let
  shared = {
    enable = true;

    # Core features the Dux defaults ship with. See the header for the cost of
    # each: these select dependencies and widget sets, not the theme itself.
    enableSystemMonitoring = true; # system monitoring widgets
    enableVPN = true; # VPN management widget
    enableDynamicTheming = true; # wallpaper-based theming (matugen)
    enableAudioWavelength = true; # audio visualiser (cava)
    enableCalendarEvents = true; # calendar events (khal)
  };
in
{
  flake.nixosModules.dms = {
    imports = [ inputs.dms.nixosModules.default ];

    # No `systemd` block here: the HM half below owns the unit, and enabling it
    # in both halves installs `dms.service` twice.
    programs.dank-material-shell = shared;
  };

  flake.homeManagerModules.dms = {
    imports = [ inputs.dms.homeModules.default ];

    programs.dank-material-shell = shared // {
      systemd = {
        enable = true;
        # Restart the user unit when the shell package changes, so a rebuild
        # replaces the running bar instead of leaving the old store path alive
        # until the next logout.
        restartIfChanged = true;
      };
    };
  };
}
