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
            imports = with self.homeManagerModules; [
              nvf
              omp
              agent-browser
              herdr-web
              programming
              fish
              nushell
              opencode
              waylandBase
              stylix
              retrosmartCursor
            ];

            # The home-manager option tree of this user, read back by nixd
            # (modules/features/nvf/_nixd.nix). The imported feature modules
            # above exist only in this evaluated submodule — the submodule
            # *type* of `home-manager.users` carries the shared modules alone —
            # so no other expression can reach `programs.nvf` or `stylix`.
            options.dendritic.nixdOptionTree = lib.mkOption {
              type = lib.types.raw;
              internal = true;
            };

            config = {
              home = {
                username = userName;
                homeDirectory = "/home/${userName}";
                stateVersion = "25.05";
              };
              dendritic.nixdOptionTree = options;
            };
          };
      };
    };
}
