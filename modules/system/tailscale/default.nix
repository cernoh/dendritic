# Tailscale VPN, ported from the Mac's pre-dendritic configuration.nix.
# Auth is interactive: run `sudo tailscale up` once per machine after the
# first switch that includes this module.
{
  self,
  ...
}:
{
  flake.nixosModules.tailscale =
    {
      lib,
      ...
    }:
    {
      services.tailscale.enable = lib.mkDefault true;
    };
}
