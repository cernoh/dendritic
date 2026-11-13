# GTK and Qt theming — handed to the Dux shell's dynamic theming.
#
# The flake palette lives in modules/features/scheme and is the build-time
# source for everything nix renders itself (nvf, zellij, tmux, omp, the greetd
# greeter, swaylock, the shell's own fallbacks). GTK, Qt, the compositor and the
# terminal are NOT rendered from it any more: DMS's dynamic theming (matugen,
# `programs.dank-material-shell.enableDynamicTheming`) writes those files at
# runtime from the current wallpaper, so a wallpaper change recolours the whole
# session instead of waiting for a rebuild.
#
# Why stylix's own `targets.gtk` and `targets.qt` are off:
# - `targets.gtk` renders `~/.config/gtk-{3,4}.0/gtk.css` as a store symlink.
#   DMS's `gtk.sh` refuses to touch a user-managed `gtk.css` symlink (it says so
#   and leaves it alone), so leaving the target on pins GTK to the build-time
#   palette and silently drops every matugen colour. With it off, DMS creates
#   `gtk.css` as a real file and owns GTK's colours.
# - `targets.qt` writes a Kvantum theme plus the qt5ct/qt6ct `custom_palette`
#   settings. DMS writes `~/.config/qt6ct/colors/matugen.conf` and its own
#   `qt6ct.conf`; two owners of the same file drift. It also sets
#   `QT_STYLE_OVERRIDE=kvantum` (NixOS half), which beats qt6ct and would leave
#   Qt apps on Kvantum colours no matter what matugen generates.
#
# What stylix still provides is the non-colour scaffolding those targets also
# gave us, now written explicitly below: HM's `gtk` options (stage GTK's theme,
# font and GTK4 mirroring) and a `qt` module pointed at `qt6ct`, the platform
# theme whose config DMS writes. Font and icon choices keep coming from the
# `stylix.fonts` / `stylix.icons` options, so nothing about them is duplicated
# here.
#
# Empty on purpose elsewhere: `autoEnable = false` keeps stylix off every
# application this flake themes itself, and `homeManagerIntegration.autoImport
# = false` makes this file the only importer of the HM module.
{
  self,
  inputs,
  ...
}:
let
  # Shared by both halves: same switch, same palette.
  base = {
    enable = true;
    autoEnable = false;
    polarity = self.scheme.mode;

    # Takes the base16 attrset directly. stylix strips the leading '#'.
    base16Scheme = self.scheme.base16;
  };
in
{
  flake.nixosModules.stylix =
    { ... }:
    {
      imports = [ inputs.stylix.nixosModules.stylix ];

      stylix = base // {
        homeManagerIntegration.autoImport = false;
        # No targets: see the header. GTK/Qt colours are DMS's.
        targets = {
          gtk.enable = false;
          qt.enable = false;
        };
      };
    };

  flake.homeManagerModules.stylix =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      stylix = base // {
        targets = {
          gtk.enable = false;
          qt.enable = false;
        };
      };

      # The half of stylix's gtk target that is not colour: HM still stages
      # GTK's theme (and therefore `settings.ini`, the cursor and the font). No
      # `gtk.css` is written here — that file is DMS's now.
      #
      # `gtk.gtk4.theme` is deliberately set to null. HM renders a non-null value
      # as a store symlink at `~/.config/gtk-4.0/gtk.css`, and `gtk.sh`'s
      # `inject_dank_import` refuses a symlinked `gtk.css` ("user-managed symlink;
      # leaving it untouched") — it then exits 1 and the shell reports "Failed to
      # apply GTK". `stateVersion = "25.05"` still makes `config.gtk.theme` the
      # *default* for this option, so null has to be explicit (it is also what
      # 26.05 adopts). With it unset, DMS creates that file itself; GTK4 ignores
      # `gtk-theme-name` anyway — it reads only user CSS — so the theme import HM
      # added bought nothing that matugen's colours do not cover.
      gtk = {
        enable = true;
        theme = {
          package = pkgs.adw-gtk3;
          name = "adw-gtk3";
        };
        gtk4.theme = null;
        font = {
          inherit (config.stylix.fonts.sansSerif) name package;
          size = config.stylix.fonts.sizes.applications;
        };
      };

      # `qt6ct` is the platform theme DMS writes colours and style into
      # (`~/.config/qt6ct/qt6ct.conf` + `colors/matugen.conf`). HM's job here is
      # only the session env (`QT_QPA_PLATFORMTHEME=qt6ct`) and the package; the
      # `qt6ctSettings` option stays unset so the shell remains the only writer.
      qt = {
        enable = true;
        platformTheme.name = "qt6ct";
      };
    };
}
