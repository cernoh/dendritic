{
  self,
  inputs,
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
      vendorfw = /boot/vendorfw;
    in
    {
      networking.hostName = "ASAHI";

      # The Mac's existing login is "da" (carried over from hm-v3); unlike
      # NIXPC it must NOT default to "davr", or switch would create a second,
      # unconfigured account next to the real one.
      dendritic.userName = "da";

      hardware.asahi.peripheralFirmwareDirectory = lib.mkIf onMacAsRoot vendorfw;
      hardware.asahi.extractPeripheralFirmware = lib.mkIf onMacAsRoot true;
      # Host-specific HM features; the shared homeManager module contributes
      # nvf + omp, and `imports` concatenates across modules.
      home-manager.users.${config.dendritic.userName} = {
        imports = with self.homeManagerModules; [
          niri
          noctalia
          ghostty
          posyCursors
          widevine
        ];
        programs.noctalia.settings = import ./_noctalia-settings.nix;
      };
    };
}
