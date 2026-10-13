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

      # This machine's MangoWM facts (outputs, GPU env, monitor binds, gaps);
      # the mango feature holds the settings both hosts share (issue #245).
      dendritic.mango = import ./_mango-settings.nix;

      # Pin the kernel to the 7.1 series (resolves to 7.1.10 in the current
      # nixos-unstable pin). The default nixos-unstable kernel (6.18.x) is too
      # old for this host's hardware/driver requirements.
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # Register qemu-aarch64 via binfmt_misc so NIXPC can build ASAHI
      # (aarch64-linux) derivations locally; cross builds run foreign
      # fixup binaries under emulation.
      boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
      # btrfs userspace support for the endeavouros data disk (sdc2, Windows
      # target — entry stays until the Windows installer takes the disk).
      boot.supportedFilesystems.btrfs = true;
      environment.systemPackages = with pkgs; [
        btrfs-progs
        # BitTorrent client (Qt front end). NIXPC-only; the shared desktop
        # bundle stays without it.
        transmission_4-qt
        persepolis
      ];
      # Spare SATA data disks (sda1 + sdb1), pinned by UUID. nofail
      # keeps boot green if a disk is absent or unmountable.
      #
      # 2026-10-13 (issue #274): sda1 moved ext4 -> btrfs with zstd compression
      # and a new UUID. sdb1 is still ext4 here on purpose: it is converted in
      # a second pass (its old UUID stays valid until that mkfs runs), so this
      # entry is updated to btrfs only once the disk is actually reformatted.
      fileSystems = {
        "/mnt/2tb-storage" = {
          device = "/dev/disk/by-uuid/3121d45d-1143-4745-bfc8-7222cf4234f0";
          fsType = "ext4";
          options = [
            "nofail"
          ];
        };
        # data1 is pinned by WWN rather than by-uuid, unlike every other entry
        # here. Reason (2026-10-13, issue #274): after the ext4 -> btrfs mkfs,
        # util-linux 2.42.3 blkid cannot probe this partition at all -- it
        # returns no TYPE and no PARTUUID, so udev publishes no ID_FS_* and no
        # /dev/disk/by-uuid or by-partuuid symlink is ever created. The
        # filesystem itself is healthy: `btrfs inspect-internal dump-super
        # -f /dev/sdb1` reports the primary superblock at bytenr=65536 with
        # magic _BHRfS_M [match] and flags (WRITTEN). Only blkid is blind to it.
        # by-id is built by udev's own builtin from the drive's burned-in WWN,
        # never from blkid, so it survives every boot -- and unlike /dev/sdb1
        # it is immune to the sdX letter reordering this host actually does
        # (the disks swapped sda<->sdb between the live ISO and first boot).
        # by-uuid can be restored here if a future util-linux starts probing
        # this partition again.
        "/mnt/2tb-ext4" = {
          device = "/dev/disk/by-id/wwn-0x5000c500dcd3ea90-part1";
          fsType = "btrfs";
          options = [
            "compress=zstd"
            "noatime"
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
            prismlauncher
            easyeffects
          ];
          # Easy access to the SATA data disks mounted above: home-dir
          # symlinks for shell/yazi, plus GTK bookmarks so Thunar and GTK
          # file pickers list both mounts at top level. mkOutOfStoreSymlink
          # keeps them plain symlinks (no store copy of the disk contents).
          home.file = {
            "2tb-storage".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-storage";
            "2tb-ext4".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-ext4";
            "endeavouros".source = config.lib.file.mkOutOfStoreSymlink "/mnt/endeavouros";
            # Downloads is the landing zone for multi-GB archives (transmission,
            # persepolis, browser: the 2026-09 Trash held a 49 GiB .7z). Keep it
            # off the NVMe so one download cannot fill /. An absent data disk
            # leaves a dangling symlink, which fails loudly instead of silently
            # refilling the root filesystem. The real directory must be removed
            # before the first switch — home-manager will not clobber it.
            "Downloads".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-ext4/Downloads";
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
