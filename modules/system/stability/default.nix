# Stability bundle ported from the Mac's pre-dendritic configuration.nix
# (issue #63 inventory): compressed swap defaults and weekly SSD trim.
#
# The out-of-memory guard is GONE. earlyoom kept SIGTERM'ing the biggest
# rustc in a rebuild (issue #108: 913 MiB `jj-lib`, then 4695 MiB `pi-natives`
# with LTO=fat) even after the thresholds were relaxed to -m5/-s5 in
# hosts/ASAHI/asahiConfiguration.nix, because 7.3 GiB of RAM cannot hold one
# such process plus the nix daemon while compressed swap absorbs pressure. It
# was killing the rebuild it was meant to protect. OOM pressure is now carried
# by host swap policy (zswap + /swapfile on ASAHI) and, if that is exhausted,
# the kernel OOM killer — which reclaims rather than aborting.
# hosts/ASAHI/asahiConfiguration.nix additionally forces
# `services.earlyoom.enable = false`, so no input bump can revive the daemon.
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

      services.fstrim.enable = lib.mkDefault true;
    };
}
