# Brave browser feature, ported out of nixpc-desktop (issue #…).
#
# Opt in from a host's `home-manager.users.<name>.imports`:
#   imports = [ self.homeManagerModules.brave ];
#
# Widevine on Asahi (aarch64-linux): Brave's component updater has no
# ARM64/Linux Widevine payload, so on Asahi we point Brave at the
# widevine-cdm package's linux_arm64 CDM through the user-data pointer file
# (~/.config/BraveSoftware/Brave-Browser/WidevineCdm/
#  latest-component-updated-widevine-cdm). Its target
# (…/share/google/chrome/WidevineCdm) is the stock Chrome layout
# widevine-cdm ships and that the Firefox widevine feature reuses.
#
# x86_64 Brave auto-downloads the CDM via its own component updater, so the
# pointer file is only emitted on aarch64 — gate it on the consuming host's
# platform, not on a host name, so it tracks the actual target arch.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.brave =
    {
      pkgs,
      lib,
      ...
    }:
    let
      onAsahi = pkgs.stdenv.hostPlatform.isAarch64;
    in
    {
      programs.brave = {
        enable = true;
        commandLineArgs = [
          "--ozone-platform=wayland"
        ];
      };

      # Lazy: only forces pkgs.widevine-cdm evaluation on aarch64.
      home.file = lib.optionalAttrs onAsahi {
        ".config/BraveSoftware/Brave-Browser/WidevineCdm/latest-component-updated-widevine-cdm" = {
          text = ''{"Path":"${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm"}'';
        };
      };
    };
}
