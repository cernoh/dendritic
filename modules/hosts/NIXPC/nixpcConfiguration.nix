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

      # Kernel: `linuxPackages_latest` is a channel, not a version pin — it
      # resolves to the newest kernel series inside the pinned nixpkgs (7.2.10
      # at the 2026-10-14 pin) and moves on its own whenever the flake's
      # nixpkgs input moves. Nothing here needs hand-editing; only the lock
      # does, via `nix flake update`.
      boot.kernelPackages = pkgs.linuxPackages_latest;
      # NVIDIA userspace driver. A per-host fact, so it lives here rather than
      # in system/drivers/nvidia.nix, which stays host-agnostic (its header
      # says so and records what the wiki does and does not require).
      #
      # `latest` was chosen on 2026-10-14 to move this box off the 595
      # production branch and onto NVIDIA's new-feature branch, whose
      # user-visible gain here is VK_NV_low_latency2 revision 3 (latency and
      # stutter under Proton's VKD3D-Proton). At the 2026-10-14 pin `latest`
      # resolves to 615.78.08; `production`/`stable` are 595.104.02.
      #
      # It is a compound, not a branch and not a version pin: nixpkgs defines
      # `latest = selectHighestVersion production new_feature`, so this box
      # re-points on its own whenever the flake's nixpkgs input advances
      # new_feature. Name `new_feature` instead to hold the branch steady, or
      # `production` to return to 595.x.
      #
      # Two known driver-side defects, recorded in
      # artifacts/dawnwalker-crash-report.html, carried over from the 595
      # branch and not verified fixed on 615 — vkd3d-proton refusing the
      # title's WaveSize(64) compute shaders (`Required WaveSize range
      # [64, 64], but supported range is [32, 32]` then `Failed to create
      # Vulkan compute pipeline, hr 0x80070057`) and the libnvidia-gpucomp
      # compile spin seen on 2026-10-14. The abort and the freeze were fixed on
      # the Steam-overlay side, not here. The roll-back below 595 remains
      # `nvidiaPackages.legacy_580` (580.178.04).
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest;
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
      # Spare SATA data disks, pinned by stable path. nofail keeps boot green
      # if a disk is absent or unmountable.
      #
      # 2026-10-13 (issue #274, Phase 4): both disks are btrfs with zstd now.
      # sdb1 (data2) was the last ext4 volume; wiped and restored from
      # MIGRATION-CARRY/data-sdb-orig. Both btrfs filesystems use the new
      # mkfs.btrfs block-group-tree default, which util-linux 2.42.3 blkid
      # cannot probe (no TYPE, no by-uuid/by-partuuid symlinks), so both
      # entries pin /dev/disk/by-id WWN paths (udev-built, blkid-independent).
      fileSystems = {
        "/mnt/2tb-storage" = {
          device = "/dev/disk/by-id/wwn-0x5000c500e5f021d1-part1";
          fsType = "btrfs";
          options = [
            "compress=zstd"
            "noatime"
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
