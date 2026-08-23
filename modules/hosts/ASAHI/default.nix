{
  self,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.ASAHI = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules = with self.nixosModules; [
      desktop
      asahiConfiguration
      asahiPlatform
      niri
      noctalia
      ghostty
      programming
      noctaliaGreeter
      ({ programs.noctalia-greeter.greeter-args = "--session Niri"; })
    ];
  };
}
