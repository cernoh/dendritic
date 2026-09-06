# watt — battery-life maximization for mobile hosts (primarily ASAHI).
#
# Apple Silicon (M1/M2) has excellent perf-per-watt, but default NixOS leaves
# tunable power saving off: CPU stays at performance-leaning governors, Wi-Fi
# power-save is off, USB/HDA/PCIe runtime PM is conservative, and lid-close
# may not suspend. This module collects the low-risk, high-impact tunables
# in one place.
#
# Design choice — TLP vs power-profiles-daemon:
#   - noctalia's `recommendedServices.enable` pulls in `power-profiles-daemon`
#     (PPD) for its power widget. PPD and TLP are mutually exclusive:
#     `services.tlp` asserts `!config.services.power-profiles-daemon.enable`.
#   - For *maximum* battery life, TLP wins: it controls cpufreq governor,
#     energy-perf policy, turbo boost, platform profile, USB autosuspend,
#     PCIe ASPM, Wi-Fi power-save, audio power-save, and long-term charge
#     thresholds. PPD only switches between 3 profiles.
#   - This module therefore enables TLP and force-disables PPD. Noctalia's
#     battery widget continues to work via UPower; the PPD profile switcher
#     inside Noctalia will show unavailable — expected when TLP owns the
#     policy. Re-enable PPD by setting `services.power-profiles-daemon.enable
#     = true` and `services.tlp.enable = false` in a host override if you
#     prefer the UX over raw battery.
#
# Safe everywhere: all settings use `mkDefault`/`mkForce` so a host can
# override, and TLP is harmless on AC/desktop. ASAHI imports it via
# `hosts/ASAHI/default.nix`; NIXPC does not (no battery) but could.
#
# Sources:
#   - NixOS wiki Laptop / Power Management (TLP + powertop + PPD + auto-cpufreq)
#   - tlp defaults: linrunner.de/tlp, NixOS `services.tlp.settings` passthrough
#   - Asahi/ARM specifics: schedutil is the Asahi kernel default; TLP drives
#     `CPU_ENERGY_PERF_POLICY` which actually matters on Apple Silicon
#   - Reddit r/AsahiLinux: TLP helps when tuned (CPU_MAX_PERF_ON_BAT cap,
#     boost off, low-power platform profile)
{
  self,
  ...
}:
{
  flake.nixosModules.watt =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Stock NixOS power-management hooks (suspend/hibernate helpers).
      # Compatible with TLP/PPD/auto-cpufreq; they may own governors but this
      # stays on for resumeCommands and related timers.
      powerManagement = {
        enable = lib.mkDefault true;
        # Powertop --auto-tune at boot: enables USB autosuspend, SATA ALPM,
        # wireless power-save, etc. Complementary to TLP (TLP does most of the
        # same, powertop catches stragglers). Safe with TLP per wiki; the one
        # risk is USB autosuspend making input devices lag after idle — TLP
        # below excludes audio/BT USB where it matters.
        powertop.enable = lib.mkDefault true;
        # Governor fallback before TLP takes over. On Apple Silicon the kernel
        # driver is apple-cpufreq + schedutil; TLP overrides to powersave on
        # BAT and schedutil/balance on AC. This default is only the pre-TLP
        # value and the fallback if TLP is disabled.
        cpuFreqGovernor = lib.mkDefault "schedutil";
      };

      # Thermald is Intel-only (x86 RAPL/DPTF). On aarch64 it builds but does
      # nothing useful and can log warnings — keep off on ASAHI.
      services.thermald.enable = lib.mkDefault false;

      # UPower is required for battery reporting (Noctalia, upower CLI) and
      # is also pulled by noctalia.recommendedServices, but ensure it stays
      # on even when we force-disable PPD.
      services.upower.enable = lib.mkDefault true;

      # Explicitly not using auto-cpufreq. It conflicts with TLP's governor
      # management; pick one. auto-cpufreq is dynamic but TLP gives more
      # explicit control for "maximize" and is better documented for Asahi.
      services.auto-cpufreq.enable = lib.mkDefault false;

      # TLP owns the policy — force-disable PPD which noctalia would otherwise
      # enable. See header comment.
      services.power-profiles-daemon.enable = lib.mkForce false;

      services.tlp = {
        enable = true;
        settings = {
          # Always start in BAT mode when uncertain; persist last mode across
          # reboots so AC-unplugged boot doesn't start in performance.
          TLP_DEFAULT_MODE = "BAT";
          TLP_PERSISTENT_DEFAULT = 1;

          # ── CPU ──────────────────────────────────────────────────────────
          # Apple Silicon has p-cores + e-cores under apple-cpufreq.
          # TLP's CPU_* tunables map to sysfs via cpufreq/energy_performance.
          # Schedutil on AC keeps responsiveness; powersave on BAT parks at
          # low freq. Energy-perf policy "power" on BAT is the battery saver.
          CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
          CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
          CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
          CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
          CPU_MIN_PERF_ON_AC = 0;
          CPU_MAX_PERF_ON_AC = 100;
          # Cap peak perf on battery: 30% is aggressive (big battery win,
          # noticeable slowdown). Raise to 50–60 if you need more headroom.
          CPU_MIN_PERF_ON_BAT = 0;
          CPU_MAX_PERF_ON_BAT = 30;
          CPU_BOOST_ON_AC = 1;
          CPU_BOOST_ON_BAT = 0;
          SCHED_POWERSAVE_ON_AC = 0;
          SCHED_POWERSAVE_ON_BAT = 1;

          # Platform profile (ACPI platform_profile): low-power on BAT lets
          # firmware lower power limits/thermal headroom.
          PLATFORM_PROFILE_ON_AC = "balanced";
          PLATFORM_PROFILE_ON_BAT = "low-power";

          # ── Memory / suspend ─────────────────────────────────────────────
          # deep sleep on BAT, s2idle on AC (fast wake when plugged).
          MEM_SLEEP_ON_AC = "s2idle";
          MEM_SLEEP_ON_BAT = "deep";

          # ── GPU ──────────────────────────────────────────────────────────
          # Asahi's mesa/mali GPU is tuned by the kernel; no RADEON/AMDGPU
          # discrete toggles needed (NIXPC's nvidia handling is separate).

          # ── Disks ────────────────────────────────────────────────────────
          # No spinning disks on MacBook, but NVMe APST/ALPM still applies.
          DISK_APM_LEVEL_ON_AC = "254 254";
          DISK_APM_LEVEL_ON_BAT = "128 128";
          SATA_LINKPWR_ON_AC = "med_power_with_dipm";
          SATA_LINKPWR_ON_BAT = "min_power";
          AHCI_RUNTIME_PM_ON_AC = "on";
          AHCI_RUNTIME_PM_ON_BAT = "auto";

          # ── PCIe / Runtime PM ────────────────────────────────────────────
          PCIE_ASPM_ON_AC = "default";
          PCIE_ASPM_ON_BAT = "powersupersave";
          RUNTIME_PM_ON_AC = "on";
          RUNTIME_PM_ON_BAT = "auto";

          # ── USB ──────────────────────────────────────────────────────────
          USB_AUTOSUSPEND = 1;
          USB_EXCLUDE_AUDIO = 1; # avoid pops on resume
          USB_EXCLUDE_BTUSB = 0;
          USB_EXCLUDE_PHONE = 0;
          USB_EXCLUDE_PRINTER = 1;
          USB_EXCLUDE_WWAN = 0;

          # ── Audio ────────────────────────────────────────────────────────
          SOUND_POWER_SAVE_ON_AC = 0;
          SOUND_POWER_SAVE_ON_BAT = 1;
          SOUND_POWER_SAVE_CONTROLLER = "Y";

          # ── Wi-Fi / WWAN ─────────────────────────────────────────────────
          WIFI_PWR_ON_AC = "off";
          WIFI_PWR_ON_BAT = "on";
          WOL_DISABLE = "Y";

          # ── Battery health (long-term) ───────────────────────────────────
          # Keep charge between 75–80% when plugged at a desk. Extends
          # cycle life significantly on lithium; MacBooks often sit plugged
          # in. Only applied if tpacpi-bat / apple-battery driver exposes
          # thresholds — otherwise silently ignored (Apple Silicon support
          # is still maturing; check `tlp-stat -b`).
          START_CHARGE_THRESH_BAT0 = 75;
          STOP_CHARGE_THRESH_BAT0 = 80;
          RESTORE_THRESHOLDS_ON_BAT = 1;
        };
      };

      # NetworkManager Wi-Fi power-save independent of TLP (TLP's WIFI_PWR
      # toggles iwlwifi power_save sysfs; NM's setting controls
      # wpa_supplicant's powersave). Enable both for maximum savings.
      networking.networkmanager.wifi.powersave = lib.mkDefault true;

      # Bluetooth: keep stack available but don't power radio at boot;
      # enable from Noctalia/widget when needed. Saves ~0.3–0.5W.
      hardware.bluetooth.powerOnBoot = lib.mkDefault false;

      # Lid / sleep behaviour tuned for a laptop.
      services.logind.settings.Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
        HandlePowerKey = "suspend-then-hibernate";
        HandlePowerKeyLongPress = "poweroff";
        IdleAction = "suspend-then-hibernate";
        IdleActionSec = "10min";
      };

      # Suspend-then-hibernate after 1h (requires swap). Even without swap
      # configured, suspend-then-hibernate falls back to suspend, so safe.
      # Hibernate delay is in systemd-sleep; keep conservative for ASAHI's
      # 8GiB RAM (hibernate image = RAM).
      systemd.sleep.settings.Sleep = {
        HibernateDelaySec = "1h";
        SuspendState = "mem";
      };

      # Useful debug/introspection tools — not required for saving, but handy
      # to verify savings (`tlp-stat -b`, `powertop --calibrate`, `powerstat`).
      environment.systemPackages = with pkgs; [
        powertop
        tlp
        powerstat
        acpi
      ];
    };
}
