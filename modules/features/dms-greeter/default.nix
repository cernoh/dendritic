{ self, inputs, ... }:
{
  flake.nixosModules.dms-greeter = { pkgs, ... }: {
    services.displayManager.dux-greeter = {
      enable = true;
      package = inputs.dms-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
}