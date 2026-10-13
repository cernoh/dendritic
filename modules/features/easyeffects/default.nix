# EasyEffects, the way upstream documents a NixOS install.
#
# https://github.com/wwmm/easyeffects/wiki/Package-Repositories#nixos says
# exactly two things, and they sit on opposite sides of the flake:
#
#   home-manager: services.easyeffects.enable = true;
#   NixOS:        programs.dconf.enable = true;
#
# EasyEffects keeps its presets and autostart flag in dconf, so a system
# package (the old `easyeffects` entry in `system/audio`'s
# `environment.systemPackages`) installs the binary but nothing else: no
# preset wiring, no dconf writer, no `~/.config/easyeffects`. Hence two
# halves, exported side by side like `features/stylix`.
#
# `system/audio` imports the NixOS half, so importing audio is the whole
# enable switch; the HM half arrives through `home-manager.sharedModules`
# rather than the all-host list in `system/home-manager`, which keeps the
# switch in one place and keeps the two halves from drifting apart.
{
  self,
  ...
}:
{
  flake.nixosModules.easyeffects =
    { ... }:
    {
      # Upstream's NixOS half. EasyEffects writes and reads its state through
      # dconf; without the service the app starts but never persists a preset.
      programs.dconf.enable = true;

      # Same enable switch for the per-user half.
      home-manager.sharedModules = [ self.homeManagerModules.easyeffects ];
    };

  flake.homeManagerModules.easyeffects =
    { ... }:
    {
      # Upstream's home-manager half. This owns `home.packages.easyeffects`,
      # so the binary leaves `environment.systemPackages` in `system/audio`.
      services.easyeffects.enable = true;
    };
}
