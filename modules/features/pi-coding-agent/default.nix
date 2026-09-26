{
        self,
        ...
}:
{
        flake.nixosModules.act =
                {
                        pkgs,
                        config,
                        ...
                }:
                {
                        imports = [ self.nixosModules.docker ];

                        environment.systemPackages = [ pkgs.pi-coding-agent ];

                        home-manager.users.${config.dendritic.userName} =
                                { config, ... }:
                                {
                                        # Out-of-store symlink into this checkout
                                        home.file.".pi".source =
                                                config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/pi/home";
                                };
                };
}
