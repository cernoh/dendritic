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

        users.${userName} = {
          imports = with self.homeManagerModules; [
            nvf
            omp
            programming
            fish
            nushell
            opencode
            waylandBase
          ];
          home = {
            username = userName;
            homeDirectory = "/home/${userName}";
            stateVersion = "25.05";
          };
        };
      };
    };
}
