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
      # Ported from the Mac's pre-dendritic configuration.nix (issue #63
      # inventory; keep/drop decisions recorded 2026-08-25).
      stability
      timeSync
      tailscale
      flatpak
      obs
      portals
      ({ programs.noctalia-greeter.greeter-args = "--session Niri"; })
    ];
  };
}
