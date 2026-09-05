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
      nixpcDesktop
      nvidiaDrivers
      gaming
      programming
      mango
      noctalia
      noctaliaGreeter
      ({ programs.noctalia-greeter.greeter-args = "--session Mango"; })
      # The Docker daemon comes in through attrs/desktop -> act -> docker;
      # importing `docker` here as well would define the module twice and
      # duplicate the docker extraGroup entry (mcpContainers below only
      # needs the daemon to exist).
      mcpContainers
    ];
  };
}
