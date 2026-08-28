# Widevine DRM-enabled Firefox for ASAHI, ported from
# ~/.config/home-manager-v3/config/asahi-config.nix (issue #29).
#
# Opt in from a host (ASAHI does):
#   imports = [ self.nixosModules.widevine ];
# and/or from a home-manager configuration:
#   imports = [ self.homeManagerModules.widevine ];
#
# Firefox consumes Widevine through a GMP directory: manifest.json +
# libwidevinecdm.so laid out as gmp-widevinecdm/system-installed, with the
# library taken from widevine-cdm's linux_arm64 payload. MOZ_GMP_PATH points
# Firefox at it; ~/.widevine/WidevineCdm links the stock Chrome layout for
# anything that probes it directly.
#
# Without this, Netflix/Disney-class DRM playback is broken on Asahi Linux.
#
# Delivery (homeless-dotfiles policy #93, issue #95):
#   - NixOS side: MOZ_GMP_PATH via `environment.sessionVariables` — Firefox
#     reads the profile/user-manager channel.
#   - HM side: only the ~/.widevine/WidevineCdm pointer (app-hardcoded path).
#
# The derivation is built INSIDE the modules so it uses the consuming host's
# pkgs (allowUnfree-aware, correct platform) rather than a flake-parts
# per-system instance captured at definition time.
{ ... }: {
  # NixOS side: point the user's Firefox at the GMP directory.
  flake.nixosModules.widevine =
    {
      pkgs,
      ...
    }:
    let
      widevine-firefox = import ./_widevine-firefox.nix pkgs;
    in
    {
      environment.sessionVariables = {
        MOZ_GMP_PATH = "${widevine-firefox}/gmp-widevinecdm/system-installed";
      };
    };

  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.widevine =
    {
      config,
      pkgs,
      ...
    }:
    {
      # Store-backed out-of-store link: the target lives in /nix/store, so
      # a plain symlink chain suffices.
      home.file.".widevine/WidevineCdm".source =
        config.lib.file.mkOutOfStoreSymlink "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
    };
}
