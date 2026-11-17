# CloudRedirect: the LD_PRELOAD hook that lets Steam Cloud work for accounts
# that do not own the game, plus the Flatpak app that fronts it.
#
# The hook is chosen here (NixOS side) and mirrored by the home module's
# `~/.local/share/CloudRedirect/cloud_redirect.so` link, so what the app reports
# and what Steam actually loads stay the same file.
{ cloudredirect, cloudredirect-moon }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nix-crab;

  helpers = import ./_lib.nix;

  # Upstream's hook reads the game list only from config.yaml's AdditionalApps.
  # The moon fork additionally scans <Steam>/config/stplug-in/*.lua and
  # luaappids.yaml, which is where slsteam-moon keeps its games.
  source = if cfg.cloudredirect.moon.enable then cloudredirect-moon else cloudredirect;

  # LD_PRELOAD takes a path verbatim, so a file input's `-source` store name
  # would work, but it is opaque and the CloudRedirect app's deploy check looks
  # for a file named cloud_redirect.so. `_lib` stages it under that name; the
  # home half builds the identical derivation for its ~/.local/share link, which
  # dedupes to this same store path.
  staged = helpers.hookStaged pkgs source;
in
{
  options.programs.nix-crab.cloudredirect = {
    enable = lib.mkEnableOption "CloudRedirect";

    moon.enable = lib.mkEnableOption ''
      the cloudredirect-moon hook instead of upstream CloudRedirect. It is opt-in
      and only needed for the LuaTools stack, which keeps its games as
      stplug-in manifests rather than in config.yaml's AdditionalApps; upstream
      CloudRedirect stays the default'';
  };

  config = lib.mkIf cfg.cloudredirect.enable {
    services.flatpak.enable = true;

    # The only channel into the wrapped Steam: `programs.steam.extraEnv` is not
    # an option, upstream hands it to `pkgs.steam.override` from the injection
    # module, and that is where this lands.
    programs.nix-crab.slssteam.extraEnv.LD_PRELOAD = "${staged}/cloud_redirect.so";

    warnings =
      lib.optional (!(cfg.slssteam.enable || cfg.slssteam-moon.enable))
        "programs.nix-crab.cloudredirect is enabled but neither programs.nix-crab.slssteam nor programs.nix-crab.slssteam-moon is, so the LD_PRELOAD hook is never applied to Steam.";
  };
}
