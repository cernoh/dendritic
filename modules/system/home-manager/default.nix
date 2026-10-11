# Wires home-manager into NixOS hosts and enables this flake's HM feature
# modules for the primary user. Hosts opt in by importing `homeManager`.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.homeManager =
    {
      lib,
      config,
      ...
    }:
    let
      userName = config.dendritic.userName;
    in
    {
      imports = [ inputs.home-manager.nixosModules.default ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        # Don't clobber pre-existing dotfiles on first switch; move them aside.
        backupFileExtension = "hm-backup";

        users.${userName} =
          {
            options,
            lib,
            ...
          }:
          {
            # Both hosts share this set. A feature that runs on one host only
            # (the two herdr bridges, `wayfinder-dashboard`) is NOT listed here:
            # its NixOS module injects the matching home-manager module through
            # `home-manager.sharedModules`, so importing the NixOS module stays
            # the single enable switch and the other host never sees the
            # service or its package.
            imports = with self.homeManagerModules; [
              nvf
              agent-browser
              programming
              fish
              nushell
              opencode
              waylandBase
              stylix
              retrosmartCursor
            ];

            config = {
              home = {
                username = userName;
                homeDirectory = "/home/${userName}";
                stateVersion = "25.05";
              };
            };
          };
      };
    };
}
