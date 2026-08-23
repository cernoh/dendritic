{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nixpcConfiguration =
    {
      lib,
      ...
    }:
    {
      networking.hostName = "NIXPC";

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
      home-manager.users.davr = {
        imports = with self.homeManagerModules; [
          mango
          noctalia
          ghostty
          nixpcDesktop
          gamingTools
        ];
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
