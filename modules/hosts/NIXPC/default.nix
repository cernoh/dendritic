{
  self,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.NIXPC = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      # See core: consumes /etc/nixos/hardware-configuration.nix only when
      # evaluated on this machine; placeholder root fs elsewhere.
      (self.lib.hardwareFromMachine "x86_64-linux")

      desktop
      nixpcConfiguration
      nvidiaDrivers
      gaming
      programming
      mango
      noctalia
      ghostty
      noctaliaGreeter
      ({ programs.noctalia-greeter.greeter-args = "--session Mango"; })
      docker
      mcpContainers
    ];
  };
}
