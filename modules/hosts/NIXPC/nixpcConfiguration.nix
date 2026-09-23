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
                        # Spare SATA data disks (sda1 + sdb1 ext4), pinned by UUID. nofail
                        # keeps boot green if a disk is absent or unmountable.
                        fileSystems = {
                                "/mnt/2tb-storage" = {
                                        device = "/dev/disk/by-uuid/3121d45d-1143-4745-bfc8-7222cf4234f0";
                                        fsType = "ext4";
                                        options = [
                                                "nofail"
                                        ];
                                };
                                "/mnt/2tb-ext4" = {
                                        device = "/dev/disk/by-uuid/e0a5bb7a-02eb-448c-a625-6d4dffabce2a";
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
