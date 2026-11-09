{ self, ... }:
{
  flake.nixosModules.dux = { pkgs, ... }: {
    imports = with self.nixosModules; [ dms dms-greeter dsearch dcalendar ];
  };
  flake.homeManagerModules.dux = { config, lib, pkgs, ... }: {
    imports = with self.homeManagerModules; [ dms dsearch dcalendar ];
  };
}