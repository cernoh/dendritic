# Declarative Flatpak applications for both NixOS hosts.
#
# Import is enabling. Both host aspects inherit the shared service setup, but
# the application lists are per host: every Flatpak here is arch-bound, and an
# app the remote does not carry for the host arch makes
# flatpak-managed-install.service exit 1, which makes switch-to-configuration
# abort with status 4.
{ inputs, self, ... }:
let
  # com.obsproject.Studio publishes arches ["x86_64"] with runtime
  # org.freedesktop.Platform/x86_64/*, so it must NOT sit in a shared list —
  # ASAHI (aarch64) then fails every activation with
  # "Nothing matches com.obsproject.Studio in remote flathub".
  nixpcAppIds = [
    "com.obsproject.Studio"
    "org.vinegarhq.Sober"
  ];
in
{
  flake.flatpakPackages = {
    common = [ ];
    nixpc = nixpcAppIds;
    asahi = [ ];
  };

  flake.nixosModules.flatpakCommon = {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
      self.nixosModules.portals
    ];

    services.flatpak = {
      enable = true;
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

      # Every Flatpak here is x86_64-only. A bundle record replaces its appId
      # string, so rocks.spotifast.Spotifast is not listed as a bare id too.
      services.flatpak.packages = lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (
        nixpcAppIds
        ++ [
          rec {
            appId = "rocks.spotifast.Spotifast";
            sha256 = "ed14213d82da5b0e3e8b003c0186eea84ce88f8da9efe85db7a935b9398b3b31";
            bundle = "${pkgs.fetchurl {
              url = "https://github.com/crmne/spotifast/releases/download/v0.12.0/spotifast-v0.12.0-x86_64.flatpak";
              inherit sha256;
            }}";
          }
        ]
      );
    };

  flake.nixosModules.flatpakAsahi = {
    imports = [ self.nixosModules.flatpakCommon ];
  };
}
