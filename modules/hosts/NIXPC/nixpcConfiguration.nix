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
      # Spare SATA data disks (sda2 NTFS "2tb storage", sdc1 ext4), pinned by
      # UUID. nofail keeps boot green if a disk is absent or unmountable;
      # uid/gid give davr ownership on ntfs3 (in-kernel driver).
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
          };
          xdg.configFile."gtk-3.0/bookmarks".text = ''
            file:///mnt/2tb-storage 2tb-storage
            file:///mnt/2tb-ext4 2tb-ext4
          '';
          # Compact Noctalia variant from hm-v3 config/nixpc-noctalia.nix:
          # top-bar widget layout, cernoh/terminal plugin, Catppuccin.
          programs.noctalia.settings = {
            shell = {
              panel_anchor_bar = "main";
              panel.launcher_placement = "attached";
              launcher = {
                categories = true;
                show_icons = true;
                sort_by_usage = true;
              };
            };
            bar.main = {
              position = "top";
              thickness = 34;
              start = [
                "launcher"
                "cernoh/terminal:bar"
                "wallpaper"
                "workspaces"
              ];
              center = [ "clock" ];
              end = [
                "media"
                "tray"
                "notifications"
                "clipboard"
                "network"
                "bluetooth"
                "volume"
                "brightness"
                "battery"
                "control-center"
                "session"
              ];
            };
            # Notifications go through Noctalia's built-in daemon (claims
            # org.freedesktop.Notifications) since the mango session no
            # longer starts dunst (issue #112). Default is already true;
            # explicit so the contract survives upstream default changes.
            notification = {
              enable_daemon = true;
            };
            plugins = {
              enabled = [ "cernoh/terminal" ];
              auto_update = "none";
            };
            wallpaper = {
              enabled = true;
              directory = "~/Pictures/Wallpapers";
              default.path = "";
            };
            theme = {
              mode = "dark";
              source = "builtin";
              builtin = "Catppuccin";
            };
          };
        };
    };
}
