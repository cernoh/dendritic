{
  self,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.ASAHI = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = with self.nixosModules; [
      # Consumes /etc/nixos/hardware-configuration.nix only when evaluated
      # on this machine; placeholder root fs elsewhere. Without this gate,
      # evaluating ASAHI from NIXPC injected x86_64-linux as
      # nixpkgs.hostPlatform and refused aarch64-only packages (#16).
      (self.lib.hardwareFromMachine "aarch64-linux")

      desktop
      asahiConfiguration
      asahiPlatform
      widevine
      niri
      # MangoWM runs beside niri (issue #245): the greeter below starts mango
      # by default, niri stays installed as the second session. The feature
      # reads this host's facts from hosts/ASAHI/_mango-settings.nix.
      mango
      # Wayland + XWayland toolkit and the polkit/keyring pair. It owns the
      # portal stack for both hosts, so no direct `portals` import here (the
      # flatpak feature also imports `portals`; the import is idempotent).
      wayland
      noctalia
      ghostty
      programming
      noctaliaGreeter
      stability
      watt
      timeSync
      tailscale
      # Client half of the NIXPC build link (issue #209): the Mac schedules
      # its aarch64-linux derivations on NIXPC instead of its own single
      # build slot. The builder half is imported by hosts/NIXPC/default.nix.
      # One-time setup: the private key at /root/.ssh/remotebuild, see
      # modules/system/distributed-builds/_link.nix.
      distributedBuilds
      flatpakAsahi
      obs
      ({ services.displayManager.noctalia-greeter.greeter-args = "--session Mango"; })
    ];
  };
}
