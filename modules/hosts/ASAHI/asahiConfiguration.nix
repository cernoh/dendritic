{
  self,
  ...
}:
{
  flake.nixosModules.asahiConfiguration =
    {
      lib,
      config,
      ...
    }:
    let
      # Peripheral firmware (Wi-Fi, webcam, ambient light sensor) is dumped
      # by the Asahi installer onto the ESP at /boot/vendorfw, root-only.
      #
      # That path must never be probed directly: for any non-root user,
      # `builtins.pathExists` on it THROWS "Permission denied" (tryEval does
      # not contain it either — skill asahi-vendorfw-cross-eval-trap mode 2),
      # which would break every cross evaluation (CI, other hosts). The only
      # situation where the path is usable is a root rebuild on this machine,
      # so detect exactly that; everywhere else the platform module's neutral
      # defaults stay in effect and the path never enters derivation inputs.
      # `currentSystem or null`: pure/restricted eval drops the attribute,
      # and `getEnv` is outright forbidden there — the && short-circuit
      # keeps both untouched in CI-style evaluations, which always take
      # the neutral branch.
      evalSystem = builtins.currentSystem or null;
      onMacAsRoot = evalSystem == "aarch64-linux" && builtins.getEnv "USER" == "root";
      # Use a Nix path (not a string) so `${peripheralFirmwareDirectory}/firmware.cpio`
      # copies the ESP payload into the store at eval time — host path string
      # "/boot/vendorfw" would be evaluated inside the sandbox where /boot is
      # invisible (sandbox = true → "firmware.cpio missing!").
      vendorfw = if onMacAsRoot then /boot/vendorfw else null;
    in
    {
      networking.hostName = "ASAHI";

      # 8 GiB RAM + 5.5 GiB zram: `max-jobs = auto` (8) OOM-killed the build
      # (earlyoom SIGTERM, issue #108). 2×4 still OOM-kills `jj-lib` rustc
      # (913 MiB VmRSS, 2026-09-06 journalctl: earlyoom -m10 -s10 SIGTERM).
      # 1×2 still OOM-kills `pi-natives` rustc (4695 MiB VmRSS, 2026-09-06
      # 15:24:05 earlyoom SIGTERM with LTO=fat, codegen-units=1). Cap to
      # 1 job × 1 core; cargo -j1 keeps peak <5 GiB (single rustc).
      # NIXPC untouched (host-scoped).
      nix.settings = {
        max-jobs = 1;
        cores = 1;
      };

      # OOM guard tuning: default -m10 -s10 (10% mem+swap) is too aggressive
      # for a single 4.7 GiB rustc + 2-3 GiB nix daemon on 7.3 GiB RAM.
      # 5% lets the build use more of zram+disk swap before SIGTERM.
      services.earlyoom.freeMemThreshold = 5;
      services.earlyoom.freeSwapThreshold = 5;

      # Keep zram at 75% (5.5 GiB) and add 8 GiB disk swap on nvme0n1p5
      # (24G free, 158G total). Total swap ~13.5 GiB covers LTO peak +
      # nix daemon without earlyoom. Kernel creates /swapfile at first
      # activation if missing.
      swapDevices = [
        {
          device = "/swapfile";
          size = 8192;
        }
      ];
      # Slight zram bump to 100% (7.3 GiB) for extra headroom alongside disk.
      zramSwap.memoryPercent = lib.mkForce 100;

      # The Mac's existing login is "da" (carried over from hm-v3); unlike
      # NIXPC it must NOT default to "davr", or switch would create a second,
      # unconfigured account next to the real one.
      dendritic.userName = "da";

      # The machine's pre-dendritic standalone config ran stateVersion 25.11;
      # stateVersion must never move backwards, so this host overrides the
      # 25.05 default from system/core (issue #63).
      system.stateVersion = "25.11";

      # Carried over from the Mac's previous configuration.nix: without it
      # the built-in display's notch region misbehaves under appledrm.
      boot.kernelParams = [ "appledrm.show_notch=1" ];

      hardware.asahi.peripheralFirmwareDirectory = vendorfw;
      hardware.asahi.extractPeripheralFirmware = onMacAsRoot;
      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.${config.dendritic.userName} =
        { pkgs, ... }:
        let
          # Login notification when system.activationScripts.asahiRebootRequired
          # (see drivers/asahi.nix) flagged a pending reboot (issue #72).
          rebootNotifier = pkgs.writeShellScript "asahi-reboot-notify" ''
            [ -f /run/reboot-required ] || exit 0
            exec ${pkgs.libnotify}/bin/notify-send \
              --urgency critical --app-name asahi \
              "Reboot required" \
              "New kernel / bootchain switched but not booted yet. Save your work and reboot."
          '';
        in
        {
          imports = with self.homeManagerModules; [
            niri
            noctalia
            ghostty
            posyCursors
            clipboard
            widevine
            brave
          ];
          programs.noctalia.settings = import ./_noctalia-settings.nix;

          # One-shot at graphical login: if the flag file is present, surface a
          # desktop notification. WantedBy default.target (not
          # graphical-session.target) because Niri's session target is not
          # guaranteed to register by the time the user manager starts.
          systemd.user.services.asahi-reboot-notify = {
            Unit = {
              Description = "Notify when an asahi kernel/bootchain switch needs a reboot";
              After = [ "graphical-session.target" ];
            };
            Service = {
              Type = "oneshot";
              ExecStart = rebootNotifier;
            };
            Install.WantedBy = [ "default.target" ];
          };
        };
    };
}
