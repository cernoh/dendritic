# GTK and Qt theming through Stylix (issue #164, comment 1).
#
# The flake palette lives in modules/features/scheme. GTK and Qt applications
# take no colour flags and keep their own built-in colours, so stylix renders
# them from that palette instead: it converts self.scheme.base16 into GTK CSS
# plus a GTK theme, and into a Kvantum theme for Qt.
#
# `autoEnable = false` on purpose. The flake already themes ghostty, nvf,
# zellij, tmux, omp, mango, noctalia and the noctalia greeter from self.scheme.
# Stylix auto-enables a target for every application it finds installed, which
# would override those. Only the gtk and qt targets are enabled; add a target
# here when the owner picks one for another application.
#
# Two modules, because the two halves are not interchangeable: NixOS enables
# dconf and the system Qt platform theme, home-manager writes the GTK CSS, the
# GTK theme and the Kvantum theme. The two sides also declare different target
# arguments, so their `targets` sets are built separately.
#
# `homeManagerIntegration.autoImport = false` on purpose, so this file is the
# only importer of the home-manager module and every HM option is set here.
# The default autoImport copies a fixed list of options into each HM user and
# that list has no `targets.*.enable` entry, so the HM halves of gtk and qt
# would inherit `autoEnable = false` and stay off.
#
# Font and icon targets stay off: `targets.gtk.fonts` and `targets.qt.fonts`
# are disabled so GTK and Qt keep the fonts this flake already installs, and
# `stylix.icons` is off by default.
#
# Opt in from a host and its HM user:
#   imports = [ self.nixosModules.stylix ];            # host
#   imports = [ self.homeManagerModules.stylix ];      # home-manager user
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
        targets = {
          gtk.enable = true;
          qt.enable = true;
        };
      };
    };

  flake.homeManagerModules.stylix =
    { ... }:
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      stylix = base // {
        targets = {
          gtk = {
            enable = true;
            fonts.enable = false;
          };
          qt = {
            enable = true;
            fonts.enable = false;
          };
        };
      };
    };
}
