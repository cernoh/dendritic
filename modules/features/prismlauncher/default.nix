# Prism Launcher — Minecraft launcher (multi-instance) with its own
# theme/catpack format, so MultiMC-derived instances do not carry over.
#
# Upstream already ships `programs.prismlauncher` in Home Manager
# (modules/programs/prismlauncher.nix); this feature is just the enable
# switch plus the handful of settings this box wants. Anything exotic
# (icons, generated themes, extraPackages) goes straight into the
# upstream option, not into a local wrapper.
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.prismlauncher ];
{
  ...
}:
{
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.prismlauncher =
    {
      pkgs,
      ...
    }:
    {
      programs.prismlauncher = {
        enable = true;
        package = pkgs.prismlauncher;
        # Merged into prismlauncher.cfg by HM's crudeini activation, so the
        # GUI still writes its own keys without them being clobbered.
        # Key names are PrismLauncher's own registerSetting() names
        # (launcher/Application.cpp), not the UI labels.
        settings = {
          # Instances live on the big SATA disk (see hosts/NIXPC
          # nixpcConfiguration), not in the home dir.
          InstanceDir = "/mnt/2tb-storage/minecraft/instances";
          # Keep the console after the game exits; pack logs matter.
          AutoCloseConsole = false;
          ConsoleMaxLines = 100000;
          # JVM ceiling: leave headroom for the client itself.
          MaxMemAlloc = 4096;
        };
      };
    };
}
