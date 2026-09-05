# NIXPC desktop application suite, ported from
# ~/.config/home-manager-v3/config/nixpc-config.nix (issue #25).
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.nixpcDesktop ];
# and from a host (NIXPC does):
#   imports = [ self.nixosModules.nixpcDesktop ];
#
# Deliberately NOT here (covered elsewhere or consciously dropped):
#   - udiskie/grim/slurp/wl-clipboard-rs/brightnessctl/swaylock -> mango;
#     notifications -> noctalia daemon (dunst dropped, issue #112)
#   - playerctl/pavucontrol -> audio;  libnotify -> core
#   - eza/bat/zoxide/fzf/fastfetch/lazygit -> fish;  direnv/git -> programming
#   - ghostty, nvim, brave -> their own features
#   - swaybg + waybar configs -> dropped outright (#28)
#   - gaming tools (lutris/mangohud/gamescope/protonup-qt/wine/winetricks/
#     vulkan tools/nvidia-vaapi-driver) -> gaming-tools feature (#26)
#   - stremio-kai data package + mpv wrapper -> its own feature (#27)
#
# Session variables are NVIDIA/Wayland host-scoped and only make sense on
# this machine — that is why they live here rather than waylandBase.
# Delivery is split (homeless-dotfiles policy #93, issue #95):
#   - NixOS side: `environment.sessionVariables` reaches login shells,
#     systemd user units and the session-root compositor.
#   - Compositor spawns: the greeter-spawned mango never sources profiles
#     (issue #86 pattern), so the same vars are ALSO registered in the
#     mango feature's `settings.env` — the only channel spawn_shell children
#     inherit.
{ ... }: {
  # NixOS side: NVIDIA/Wayland GPU env for this host.
  flake.nixosModules.nixpcDesktop =
    { ... }:
    {
      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
        WLR_NO_HARDWARE_CURSORS = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        SDL_VIDEODRIVER = "wayland,x11";
        STEAM_USE_DYNAMIC_VGUI = "1";
      };
    };

  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.nixpcDesktop =
    {
      pkgs,
      ...
    }:
    {
      # NVIDIA/Wayland GPU tuning for Brave on this host; `enable` and the
      # generic --ozone-platform=wayland flag live in the brave feature.
      # commandLineArgs lists merge across modules, so the two combine.
      programs.brave.commandLineArgs = [
        "--enable-features=Vulkan,VulkanFromANGLE,DefaultANGLEVulkan,UseOzonePlatform"
        "--enable-gpu-rasterization"
        "--ignore-gpu-blocklist"
      ];

      home.packages = with pkgs; [
        firefox
        thunar
        mpv
        vlc
        spotify
        ncpamixer
        pamixer
        mission-center
        lm_sensors
        btop
        gnome-disk-utility
        ddcutil
        wob
        syshud
        nwg-look
        stremio-linux-shell
      ];
    };
}
