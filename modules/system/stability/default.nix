# Stability bundle ported from the Mac's pre-dendritic configuration.nix
# (issue #63 inventory): compressed swap, an out-of-memory guard, weekly SSD
# trim.
#
# Deliberately NOT ported from that file: tlp + auto-cpufreq. They hard-conflict
# with power-profiles-daemon, which noctalia's recommendedServices turns on;
# the accepted direction (2026-08-25) is power-profiles-daemon everywhere,
# so battery charge thresholds are dropped on ASAHI.
{
  self,
  ...
}:
{
  flake.nixosModules.stability =
    {
      lib,
      ...
    }:
    {
      zramSwap = {
        enable = lib.mkDefault true;
        memoryPercent = 75;
        algorithm = "zstd";
      };

      services.earlyoom.enable = lib.mkDefault true;

      services.fstrim.enable = lib.mkDefault true;
    };
}
