# OBS Studio with virtual camera + droidcam plugin, ported verbatim from the
# Mac's pre-dendritic configuration.nix (screen recording setup).
{
  self,
  ...
}:
{
  flake.nixosModules.obs =
    {
      pkgs,
      lib,
      ...
    }:
    {
      programs.obs-studio = {
        enable = lib.mkDefault true;
        enableVirtualCamera = true;
        plugins = with pkgs.obs-studio-plugins; [
          droidcam-obs
        ];
      };
    };
}
