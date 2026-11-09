# Dux shell (DMS) feature: bar, panels, launcher, lock screen.
#
# Both halves import the matching upstream module from `inputs.dms`
# (dux-shell) and then enable it. The option upstream publishes is
# `programs.dank-material-shell`; the older `programs.dms-shell` no longer
# exists anywhere, and defining it aborts the whole rebuild with
# ``The option `home-manager.users.<user>.programs.dms-shell' does not exist``.
#
# Split of duties — upstream defines the `dms.service` unit in BOTH halves, so
# `systemd.enable` is set on exactly one:
# - NixOS half: the system services the widgets need (UPower,
#   accounts-daemon, geoclue2, power-profiles-daemon, polkit) and the
#   system-wide packages. `systemd.enable` stays off here.
# - HM half: the user unit itself, bound to the compositor's
#   `wayland.systemd.target`.
#
# No `package` override: upstream builds dms-shell from the *consumer's* pkgs
# (`mkModuleWithDmsPkgs`), so the shell and the quickshell it runs cost one
# nixpkgs eval. `inputs.dms.packages.<system>.default` would instead build
# against dux-shell's own locked nixpkgs — a second Qt tree, for an upstream
# that has no binary cache to substitute from.
{ self, inputs, ... }:
{
  flake.nixosModules.dms = {
    imports = [ inputs.dms.nixosModules.default ];

    programs.dank-material-shell.enable = true;
  };

  flake.homeManagerModules.dms = {
    imports = [ inputs.dms.homeModules.default ];

    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;
    };
  };
}
