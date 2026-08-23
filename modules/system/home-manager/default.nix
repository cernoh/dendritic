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
      ...
    }:
    {
      imports = [ inputs.home-manager.nixosModules.default ];

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        # Don't clobber pre-existing dotfiles on first switch; move them aside.
        backupFileExtension = "hm-backup";

        users.davr = {
          imports = with self.homeManagerModules; [
            nvf
            omp
          ];
          home = {
            username = "davr";
            homeDirectory = "/home/davr";
            stateVersion = "25.05";
          };
        };
      };
    };
}
