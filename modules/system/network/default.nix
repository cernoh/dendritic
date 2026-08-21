{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.network = {
    pkgs,
    lib,
    ...
  }: {
    ##TODO: add nextdns with agenix
    networking = {
      networkmanager = {
        enable = true;
        dns = "nextdns";
      };
      nameservers = [
      ];
      firewall.enable = false;
    };
    services.unbound = {
      enable = true;
    };

    systemd.services.NetworkManager-wait-online.enable = false;
  };
}
