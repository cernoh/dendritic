# Widevine DRM-enabled Firefox for ASAHI, ported from
# ~/.config/home-manager-v3/config/asahi-config.nix (issue #29).
#
# Opt in from a home-manager configuration:
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
# The derivation is built INSIDE the HM module so it uses the consuming
# host's pkgs (allowUnfree-aware, correct platform) rather than a
# flake-parts per-system instance captured at definition time.
{ ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.widevine =
    {
      config,
      pkgs,
      ...
    }:
    let
      widevine-firefox = pkgs.stdenv.mkDerivation {
        name = "widevine-firefox";
        version = pkgs.widevine-cdm.version;

        buildCommand = ''
          mkdir -p $out/gmp-widevinecdm/system-installed
          ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/manifest.json" \
                $out/gmp-widevinecdm/system-installed/manifest.json
          ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_arm64/libwidevinecdm.so" \
                $out/gmp-widevinecdm/system-installed/libwidevinecdm.so
        '';

        meta = pkgs.widevine-cdm.meta // {
          platforms = [ "aarch64-linux" ];
        };
      };
    in
    {
      home = {
        sessionVariables = {
          MOZ_GMP_PATH = "${widevine-firefox}/gmp-widevinecdm/system-installed";
        };

        # Store-backed out-of-store link: the target lives in /nix/store, so
        # a plain symlink chain suffices.
        file.".widevine/WidevineCdm".source =
          config.lib.file.mkOutOfStoreSymlink "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm";
      };
    };
}
