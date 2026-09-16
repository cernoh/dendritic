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
      flatpak
      obs
      portals
      ({ programs.noctalia-greeter.greeter-args = "--session Niri"; })
    ];
  };
}
