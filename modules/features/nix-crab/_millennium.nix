# Millennium: the Steam client modding framework (themes + plugins).
#
# Enabled it replaces the base Steam package through an overlay, which is the
# only place it can go: `programs.steam.package` is already defined by the
# injection module, and two definitions of one option is an eval error. Being
# the base is also what makes the two stack — slssteam still calls
# `pkgs.steam.override`, and Millennium's own wrapper merges `extraEnv` instead
# of replacing it, so LD_AUDIT (SLSsteam) and LD_PRELOAD (CloudRedirect) survive
# alongside MILLENNIUM_RUNTIME_PATH.
{ millennium }:
{
  config,
  lib,
  ...
}:
{
  options.programs.nix-crab.millennium.enable =
    lib.mkEnableOption "Millennium (Steam themes and plugins)";

  config = lib.mkIf config.programs.nix-crab.millennium.enable {
    nixpkgs.overlays = [
      millennium.overlays.default
      (final: prev: {
        steam = final.millennium-steam;
      })
    ];

    # Working plugins and themes are the home module's option lists; this half
    # is only the framework. Without an injection module enabling steam, the
    # overlay swaps a package nothing installs.
    warnings =
      lib.optional
        (!(config.programs.nix-crab.slssteam.enable || config.programs.nix-crab.slssteam-moon.enable))
        "programs.nix-crab.millennium is enabled but no injection is, and this module does not set programs.steam.enable — enable programs.nix-crab.slssteam as well.";
  };
}
