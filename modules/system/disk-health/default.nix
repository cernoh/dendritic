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
#   usable by root and by the smartd daemon.
#
# - `services.smartd`, which autodetects every attached device at startup
#   (`DEVICESCAN`, the nixpkgs default) and reports failures. nixpkgs already
#   defaults the notification path to `wall` and leaves mail off, which is
#   right here: these hosts have no MTA. `-n standby` is appended so the
#   daemon does not spin up an idle HDD just to poll it; NVMe ignores it.
#
# - The plugin's read-only root collector, as a declared
#   `noctalia-drive-health.{service,timer}` pair. The plugin cannot install it
#   here: its installer writes unit files into `/etc/systemd/system`, which on
#   NixOS is a symlink to the read-only `/nix/store/...-system-units`, so the
#   install dies with `Read-only file system` after it has already staged its
#   scripts into `/usr/local/libexec/noctalia-drive-health/`. That half-finished
#   install leaves the plugin reporting `installed = true` with no unit behind
#   it, so the panel sits on `stale` forever. This module declares the unit pair
#   and stages the collector script the plugin tests for, which is what makes
#   the panel read a fresh `/run/noctalia-drive-health/raw.json` (schema 2,
#   `collector_version` 2.0.1) and report `healthy`.
#
# The plugin's own lifecycle scripts are the other half of that contract: they
# call `systemctl enable`/`disable`, write a timer drop-in under
# `/etc/systemd/system/`, and uninstall by `rm -rf`-ing `/usr/local/libexec`.
# None of those can work on NixOS, and the plugin re-issues `start` on every
# shell start, so leaving them in place means an error notification per login.
# The activation script below therefore replaces them, at the same paths, with
# the three NixOS-aware equivalents defined here.
{ ... }:
{
  flake.nixosModules.diskHealth =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.noctaliaDriveHealth;

      userName = config.dendritic.userName;
      userHome = config.users.users.${userName}.home;
      userGroup = config.users.users.${userName}.group;

      serviceName = "noctalia-drive-health";
      # Plugin contracts, not NixOS choices: `collector.luau` resolves the
      # installed marker and the lifecycle scripts under `SYSTEM_LIBEXEC`, and
      # reads `RAW_CACHE`.
      libexecDir = "/usr/local/libexec/${serviceName}";
      runtimeDir = "/run/${serviceName}";

      # The shell materializes the plugin from its source, and the source
      # directory name (`community`) is not a contract, so the activation
      # script globs for it.
      materializedRoot = "${userHome}/.local/state/noctalia/plugins/materialized";

      coreutils = "${pkgs.coreutils}/bin";
      systemctl = lib.getExe' config.systemd.package "systemctl";

      # `manage-collector.sh`: the panel's start/pause control. `start` is
      # re-issued by the plugin's `onEnable` on every shell start, so it must
      # stay quiet and idempotent. `pause` stops the pair until the next boot
      # instead of the plugin's `systemctl disable`, which cannot write the
      # `timers.target.wants` symlink it needs.
      manageScript = pkgs.writeShellScript "${serviceName}-manage" ''
        set -eu
        if [ "$(${coreutils}/id -u)" -ne 0 ]; then
          echo "Run this command through the administrator authorization dialog." >&2
          exit 1
        fi
        if [ "$#" -ne 1 ]; then
          echo "usage: $0 {start|pause}" >&2
          exit 2
        fi
        case "$1" in
          start)
            ${systemctl} start ${serviceName}.timer
            ${systemctl} start ${serviceName}.service
            echo "Started the Noctalia Drive Health collector."
            ;;
          pause)
            ${systemctl} stop ${serviceName}.timer
            ${systemctl} stop ${serviceName}.service
            echo "Paused the Noctalia Drive Health collector until the next boot."
            ;;
          *)
            echo "usage: $0 {start|pause}" >&2
            exit 2
            ;;
        esac
      '';

      # `set-collector-interval.sh`: the panel's interval control. A drop-in for
      # a unit that lives in the store can only be written under /run, so a
      # change here lasts until the next boot and then
      # `services.noctaliaDriveHealth.intervalMinutes` applies again.
      intervalScript = pkgs.writeShellScript "${serviceName}-interval" ''
        set -eu
        if [ "$(${coreutils}/id -u)" -ne 0 ]; then
          echo "Run this command with sudo." >&2
          exit 1
        fi
        if [ "$#" -ne 1 ]; then
          echo "usage: $0 MINUTES (1-1440)" >&2
          exit 2
        fi
        minutes="$1"
        case "$minutes" in
          "" | *[!0-9]*)
            echo "usage: $0 MINUTES (1-1440)" >&2
            exit 2
            ;;
        esac
        if [ "$minutes" -lt 1 ] || [ "$minutes" -gt 1440 ]; then
          echo "Interval must be a whole number of minutes from 1 to 1440." >&2
          exit 2
        fi
        dropinDir="/run/systemd/system/${serviceName}.timer.d"
        ${coreutils}/install -d -m0755 "$dropinDir"
        # Resetting a monotonic timer also drops OnBootSec from the base unit,
        # so the drop-in restores both triggers.
        printf '[Timer]\nOnUnitActiveSec=\nOnBootSec=20s\nOnUnitActiveSec=%smin\n' "$minutes" >"$dropinDir/interval.conf"
        ${systemctl} daemon-reload
        ${systemctl} restart ${serviceName}.timer
        ${systemctl} start ${serviceName}.service
        echo "Noctalia full SMART refresh interval set to $minutes minute(s) until the next boot."
      '';

      # `uninstall-collector.sh`: the panel's remove control. A unit declared in
      # the flake cannot be removed from the machine, and the plugin's own
      # uninstaller would `rm -rf` the staged collector and leave the timer
      # failing on a missing ExecStart, so this one stops the pair and names the
      # declaration instead.
      uninstallScript = pkgs.writeShellScript "${serviceName}-uninstall" ''
        set -eu
        if [ "$(${coreutils}/id -u)" -ne 0 ]; then
          echo "Run this uninstaller with sudo." >&2
          exit 1
        fi
        ${systemctl} stop ${serviceName}.timer || true
        ${systemctl} stop ${serviceName}.service || true
        echo "Stopped the Noctalia Drive Health collector." >&2
        echo "It is declared in the NixOS configuration (modules/system/disk-health)," >&2
        echo "so it cannot be removed from here. Drop the module from the host's" >&2
        echo "import list and rebuild to uninstall it." >&2
      '';
    in
    {
      options.services.noctaliaDriveHealth.intervalMinutes = lib.mkOption {
        type = lib.types.ints.between 1 1440;
        default = 15;
        description = ''
          Minutes between full SMART refreshes by the noctalia drive-health
          collector. This is the durable value: the panel's own interval control
          writes a drop-in under {file}`/run`, which this replaces at the next
          boot.
        '';
      };

      config = {
        environment.systemPackages = [ pkgs.smartmontools ];

        services.smartd = {
          enable = true;
          defaults.monitored = "-a -n standby";
        };

        systemd.services.${serviceName} = {
          description = "Collect read-only SMART data for Noctalia Drive Health";
          documentation = [ "man:smartctl(8)" ];
          after = [ "local-fs.target" ];
          # The collector calls `lsblk` and `smartctl` by bare name. nixpkgs'
          # default service PATH (coreutils, findutils, gnugrep, gnused,
          # systemd) has neither, so both are appended to it.
          path = lib.mkAfter [
            pkgs.smartmontools
            pkgs.util-linux
          ];
          # No `wantedBy`: the timer is the only thing that pulls this in, so a
          # pause from the panel stays paused instead of being restarted by
          # multi-user.target. A missing collector (the plugin is not
          # materialized yet) skips the unit rather than failing the timer.
          unitConfig.ConditionPathExists = "${libexecDir}/collect_raw.sh";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "/bin/sh ${libexecDir}/collect_raw.sh --output ${runtimeDir}/raw.json";
            Group = userGroup;
            RuntimeDirectory = serviceName;
            RuntimeDirectoryMode = "0750";
            # Load-bearing: without it systemd removes the directory when the
            # oneshot exits and the plugin has no cache to read.
            RuntimeDirectoryPreserve = true;
            UMask = "0027";
            StandardOutput = "null";
            StandardError = "journal";
            TimeoutStartSec = "60s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            PrivateNetwork = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            ProtectClock = true;
            RestrictAddressFamilies = [ "AF_UNIX" ];
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            CapabilityBoundingSet = [
              "CAP_DAC_OVERRIDE"
              "CAP_SYS_ADMIN"
              "CAP_SYS_RAWIO"
            ];
            ReadWritePaths = [ runtimeDir ];
          };
        };

        systemd.timers.${serviceName} = {
          description = "Refresh SMART data for Noctalia";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            Unit = "${serviceName}.service";
            OnBootSec = "20s";
            OnUnitActiveSec = "${toString cfg.intervalMinutes}min";
            AccuracySec = "5s";
          };
        };

        # Stages what the plugin's installer cannot, and puts the three
        # lifecycle replacements at the paths the plugin already resolves. The
        # collector is copied out of the user's materialized plugin tree into a
        # root-owned path, exactly as the plugin's own installer does, because
        # the service runs it as root.
        system.activationScripts.noctaliaDriveHealth = {
          deps = [ "users" ];
          text = ''
            export PATH="${lib.makeBinPath [ pkgs.coreutils ]}:$PATH"
            collectorSource=""
            for candidate in ${materializedRoot}/*/drive-health; do
              if [ -r "$candidate/scripts/collect_raw.sh" ]; then
                collectorSource="$candidate"
                break
              fi
            done
            install -d -m0755 ${libexecDir}
            if [ -n "$collectorSource" ]; then
              install -m0755 "$collectorSource/scripts/collect_raw.sh" ${libexecDir}/collect_raw.sh
              install -m0755 "$collectorSource/packaging/smart-action.sh" ${libexecDir}/smart-action.sh
            else
              echo "noctalia drive-health: plugin not materialized under ${materializedRoot}, collector not staged" >&2
            fi
            ln -sfn ${manageScript} ${libexecDir}/manage-collector.sh
            ln -sfn ${intervalScript} ${libexecDir}/set-collector-interval.sh
            ln -sfn ${uninstallScript} ${libexecDir}/uninstall-collector.sh
          '';
        };
      };
    };
}
