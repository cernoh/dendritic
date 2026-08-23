{
  self,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.NIXPC = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.nixosModules; [
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
    ];
  };
}
