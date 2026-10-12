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

      # This machine's MangoWM facts (the panel's scale, niri's gaps and ring
      # width); the mango feature holds the settings both hosts share
      # (issue #245).
      dendritic.mango = import ./_mango-settings.nix;

      # Build parallelism: 8 vCPU (Blizzard-M2 + Avalanche-M2, no SMT), 7.3 GiB
      # RAM, ~15 GiB of swap (zram + /swapfile below). `cores = 0` is the load-
      # bearing half — it hands a single heavy derivation the whole box, which
      # is exactly what the Asahi kernel build needs now that the distributed-
      # builds link is gone and the Mac owns every derivation it installs.
      # `max-jobs = 4` rides the same shape system/core/nix-settings.nix picks
      # for every host, and swap is what absorbs the RAM overshoot that a
      # 4x8 process table implies.
      #
      # These used to be `mkForce 1`/`mkForce 1` (issue #108): earlyoom kept
      # SIGTERM'ing the biggest rustc, so the box was pinned to a single job
      # with a single core. With earlyoom retired (below) that ceiling only
      # made the rebuild slow.
      #
      # NIXPC untouched (host-scoped) — but the NIXPC-shaped defaults in
      # system/core/nix-settings.nix are a plain definition, so these must
      # outrank them or both hosts conflict on the option.
      nix.settings = {
        max-jobs = lib.mkForce 4;
        cores = lib.mkForce 0;
      };

      # This machine builds everything itself and nothing else. Forcing the
      # list empty is what makes that durable: the link used to arrive through
      # the `distributedBuilds` module (system/distributed-builds/client.nix),
      # which set `nix.buildMachines` from _link.nix. hosts/ASAHI/default.nix
      # no longer imports that module, and this force means no future import,
      # overlay or `nix.extra-platforms` can quietly hand work to NIXPC again.
      # The Mac already advertises `big-parallel` (nixpkgs' default
      # `nix.settings.system-features`), which is the only feature gate that
      # matters here — linux-asahi/uboot-asahi carry
      # requiredSystemFeatures = [ "big-parallel" ], and nixos-apple-silicon.
      # cachix.org caches none of them, so those four derivations are built
      # locally on every asahi input bump (issue #72/#73). That is deliberate.
      nix.buildMachines = lib.mkForce [ ];

      # `nix.buildMachines = []` means "write no /etc/nix/machines" (see
      # nix-remote-build.nix), not "write an empty one", and `builders`
      # defaults to `@/etc/nix/machines` — so a machines file left behind by an
      # older generation is still honoured. Pin the `builders` setting itself
      # to empty so the running daemon ignores that file whether or not it is
      # there. That is what makes "never builds remotely" true from the first
      # build after this generation, with no --builders flag needed. There is no
      # `build-machines` setting; `builders` is the name, and an empty value is
      # accepted (`nix --option builders "" config show builders`).
      nix.settings.builders = lib.mkForce "";

      # earlyoom retired (issue #108 follow-up). It aborted the rebuild it was
      # meant to protect: even at -m5/-s5 it SIGTERM'd a 4.7 GiB `pi-natives`
      # rustc on a 7.3 GiB box. zramSwap at 100% plus the 8 GiB /swapfile below
      # is the memory policy now; past that the kernel reclaims. Forced, not
      # defaulted, so an input bump cannot quietly turn the daemon back on.
      services.earlyoom.enable = lib.mkForce false;

      # Swap is the memory policy now that earlyoom is gone (issue #108): zram
      # at 100% (7.3 GiB) plus an 8 GiB /swapfile on nvme0n1p5 (24G free, 158G
      # total) gives ~15 GiB, enough for an LTO-fat rustc plus the nix daemon at
      # max-jobs = 4. The kernel creates /swapfile at first activation if
      # missing. See the earlyoom note above for why the daemon no longer backs
      # this up.
      swapDevices = [
        {
          device = "/swapfile";
          size = 8192;
        }
      ];
      # zram bumped to 100% (7.3 GiB) for headroom alongside the disk swap.
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

      # 477M ESP + 65M Asahi Image.efi / 26M initrd per generation → 6 gens
      # already occupies 352M and blocks switch with ENOSPC (2026-09-06).
      # Cap to 3 so boot adds ~270M + 123M fixed (m1n1/asahi/vendorfw) < ESP.
      boot.loader.systemd-boot.configurationLimit = 3;

      hardware.asahi.peripheralFirmwareDirectory = vendorfw;
      hardware.asahi.extractPeripheralFirmware = onMacAsRoot;
      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.${config.dendritic.userName} =
        { pkgs, config, ... }:
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
          home.packages = [ pkgs.evremap ];

          # ASAHI-only: ambient-light auto brightness. Out-of-store like the
          # terminal plugin, so edits stay live. The plugins.enabled entry in
          # _noctalia-settings.nix turns it on; NIXPC gets neither.
          home.file.".local/share/noctalia/plugins/auto-brightness".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/noctalia/plugins/auto-brightness";

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

          # Evremap configuration to remap Ctrl+2 to @ and Option+3 to #.
          home.file.\".config/evremap.conf\".source = pkgs.writeText "evremap.conf" ''
            event {
              key two {
                control + at
              }
              key 3 {
                alt + numbersign
              }
            }
          '';

          home.sessionCommands = [
            ''
              evremap /home/da/.config/evremap.conf &
            ''
          ];
        };
    };
}
