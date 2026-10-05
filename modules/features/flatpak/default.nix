# Declarative Flatpak applications for both NixOS hosts.
#
# Import is enabling. Both host aspects inherit the shared service setup and
# application list; host-only applications stay in their host aspect.
{ inputs, self, ... }:
let
  commonPackages = [ "com.obsproject.Studio" ];
  nixpcPackages = commonPackages ++ [
    "org.vinegarhq.Sober"
    "rocks.spotifast.Spotifast"
  ];
in
{
  flake.flatpakPackages = {
    common = commonPackages;
    nixpc = nixpcPackages;
    asahi = commonPackages;
  };

  flake.nixosModules.flatpakCommon = {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
      self.nixosModules.portals
    ];

    services.flatpak = {
      enable = true;
      packages = commonPackages;
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };

  flake.nixosModules.flatpakNixpc =
    { lib, pkgs, ... }:
    {
      imports = [ self.nixosModules.flatpakCommon ];

      # Sober and Spotifast's Flatpak bundle are available only on x86_64.
      services.flatpak.packages = lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
        "org.vinegarhq.Sober"
        rec {
          appId = "rocks.spotifast.Spotifast";
          sha256 = "ed14213d82da5b0e3e8b003c0186eea84ce88f8da9efe85db7a935b9398b3b31";
          bundle = "${pkgs.fetchurl {
            url = "https://github.com/crmne/spotifast/releases/download/v0.12.0/spotifast-v0.12.0-x86_64.flatpak";
            inherit sha256;
          }}";
        }
      ];
    };

  flake.nixosModules.flatpakAsahi = {
    imports = [ self.nixosModules.flatpakCommon ];
  };
}
