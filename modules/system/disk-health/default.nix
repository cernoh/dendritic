# SMART disk health for hosts with real storage.
#
# Opt in from a host's module list:
#   imports = [ self.nixosModules.diskHealth ];
#
# What this owns:
#
# - `smartmontools`. `smartctl` is the dependency the noctalia
#   `gustav0ar/drive-health` plugin declares in `plugin.toml` and refuses to
#   collect without (its collector logs `Dependency check found missing
#   commands: smartctl (smartctl)`). Note the unprivileged limit it does not
#   remove: `smartctl --all /dev/sd*` and `/dev/nvme*` fail with
#   `Permission denied` for the desktop user, so `smartctl` alone is only
#   usable by root and by the smartd daemon. The plugin's full-SMART data
#   comes from its own root collector, not from this package — see below.
#
# - `services.smartd`, which autodetects every attached device at startup
#   (`DEVICESCAN`, the nixpkgs default) and reports failures. nixpkgs already
#   defaults the notification path to `wall` and leaves mail off, which is
#   right here: these hosts have no MTA. `-n standby` is appended so the
#   daemon does not spin up an idle HDD just to poll it; NVMe ignores it.
#
# What this deliberately does NOT own: the drive-health plugin's own
# read-only root collector, which writes the cache the plugin reads
# (`/run/noctalia-drive-health/raw.json`, schema 2). That collector is
# installed and managed from the plugin's UI through polkit and owns
# `/usr/local/libexec/noctalia-drive-health/` plus
# `/etc/systemd/system/noctalia-drive-health.{service,timer}`. Declaring a
# second unit of the same name here would not satisfy the plugin's
# `installed` check (it tests for its own `collect_raw.sh`) and would be
# shadowed by the plugin's start/pause/remove controls. The one thing that
# blocked that installer was the missing `smartctl`; installing it is the
# whole declarative fix. See modules/features/noctalia/AGENTS.md.
{ ... }:
{
  flake.nixosModules.diskHealth =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.smartmontools ];

      services.smartd = {
        enable = true;
        defaults.monitored = "-a -n standby";
      };
    };
}
