# Nautilus file manager, replacing Thunar (issue #164, comment 2).
#
# Brave opens the folder that holds a download through the
# `org.freedesktop.FileManager1` D-Bus service, and falls back to `xdg-open`.
# Nautilus implements that service, so naming it the default handler for
# `inode/directory` makes Brave open Nautilus.
#
# A system package on purpose, not a home-manager one. The greeter spawns the
# compositor and it never sources a shell profile (issue #86), so a package
# from a user profile is not guaranteed to reach that process's PATH or
# XDG_DATA_DIRS. A system package sits in `/run/current-system/sw` and is
# visible to every session on the host.
#
# Opt in from a host, or from a bundle:
#   imports = [ self.nixosModules.nautilus ];
{ ... }: {
  flake.nixosModules.nautilus =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.nautilus ];

      # gvfs backs the trash, network and removable-media locations that
      # Nautilus lists in its sidebar.
      services.gvfs.enable = true;

      xdg.mime.defaultApplications."inode/directory" = [ "org.gnome.Nautilus.desktop" ];
    };
}
