{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nixpcConfiguration =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      networking.hostName = "NIXPC";

      # Pin the kernel to the 7.1 series (resolves to 7.1.10 in the current
      # nixos-unstable pin). The default nixos-unstable kernel (6.18.x) is too
      # old for this host's hardware/driver requirements.
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # Register qemu-aarch64 via binfmt_misc so NIXPC can build ASAHI
      # (aarch64-linux) derivations locally; cross builds run foreign
      # fixup binaries under emulation.
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      # btrfs userspace + kernel support for the endeavouros data disk (sdc2);
      # ntfs3g ships ntfsfix for clearing the NTFS dirty flag when the
      # in-kernel ntfs3 driver refuses to mount 2tb-storage (sdb2).
      boot.supportedFilesystems.btrfs = true;
      environment.systemPackages = with pkgs; [
        ntfs3g
        btrfs-progs
      ];
      # Spare SATA data disks (sda1 ext4, sdb2 NTFS "2tb storage", sdc2 btrfs
      # endeavouros), pinned by UUID. nofail keeps boot green if a disk is
      # absent or unmountable; uid/gid give davr ownership on ntfs3
      # (in-kernel driver).
      # NOTE: if /mnt/2tb-storage fails with "wrong fs type, bad superblock",
      # the NTFS volume has its dirty flag set (unclean Windows shutdown).
      # Clear it with: sudo ntfsfix /dev/disk/by-uuid/DE82B0B582B0938D
      # then: sudo systemctl restart mnt-2tb\\x2dstorage.mount
      # Keep sdb2 data intact; sdc2 (endeavouros) is the wipe candidate.
      fileSystems = {
        "/mnt/2tb-storage" = {
          device = "/dev/disk/by-uuid/DE82B0B582B0938D";
          fsType = "ntfs3";
          options = [
            "uid=1000"
            "gid=100"
            "umask=022"
            "nofail"
          ];
        };
        "/mnt/2tb-ext4" = {
          device = "/dev/disk/by-uuid/5cd547ee-7ee6-47e6-9de5-0d922d7fea10";
          fsType = "ext4";
          options = [
            "nofail"
          ];
        };
        "/mnt/endeavouros" = {
          device = "/dev/disk/by-uuid/c6c7f349-20be-44aa-93da-0b358cb61b7b";
          fsType = "btrfs";
          options = [
            "nofail"
          ];
        };
      };
      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.${config.dendritic.userName} =
        { config, ... }:
        {
          imports = with self.homeManagerModules; [
            noctalia
            ghostty
            nixpcDesktop
            brave
            gamingTools
            stremioKai
          ];
          # Easy access to the SATA data disks mounted above: home-dir
          # symlinks for shell/yazi, plus GTK bookmarks so Thunar and GTK
          # file pickers list both mounts at top level. mkOutOfStoreSymlink
          # keeps them plain symlinks (no store copy of the disk contents).
          home.file = {
            "2tb-storage".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-storage";
            "2tb-ext4".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-ext4";
            "endeavouros".source = config.lib.file.mkOutOfStoreSymlink "/mnt/endeavouros";
          };
          xdg.configFile."gtk-3.0/bookmarks".text = ''
            file:///mnt/2tb-storage 2tb-storage
            file:///mnt/2tb-ext4 2tb-ext4
            file:///mnt/endeavouros endeavouros
          '';
          # Noctalia shell settings: the full exported shell configuration of
          # this host lives in _noctalia-settings.nix (the same convention as
          # hosts/ASAHI/_noctalia-settings.nix).
          programs.noctalia.settings = import ./_noctalia-settings.nix;
        };
    };
}
