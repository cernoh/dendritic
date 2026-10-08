{
        self,
        inputs,
        ...
}:
{
        flake.nixosModules.pi-coding-agent =
                {
                        pkgs,
                        lib,
                        config,
                        ...
                }:
                {
                        environment.systemPackages = [
                                pkgs.pi-coding-agent
                                pkgs.nodejs
                        ];

                        home-manager.users.${config.dendritic.userName} =
                                { config, ... }:
                                let
                                        # A NixOS module's `lib` has no `hm`; home-manager's own dag does,
                                        # through the input. Same value omp uses, reached from a NixOS module.
                                        hmDag = inputs.home-manager.lib.hm.dag;
                                in
                                {
                                        # Out-of-store symlink into this checkout
                                        home.file.".pi".source =
                                                config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/pi-coding-agent/home";

                                        # pi TUI theme, from features/scheme (see `self.scheme.pi`). Pi needs
                                        # all 53 color tokens and falls back to its built-in `dark` theme for
                                        # any missing one, so the map lives in the scheme rather than next to
                                        # this module. ~/.pi is the out-of-store symlink, and agent/themes/
                                        # is gitignored there, so the generated file never dirties the
                                        # checkout. pi hot-reloads the active theme on edit, so a palette
                                        # change in self.scheme reaches the next run.
                                        home.activation.piTheme = hmDag.entryAfter [ "writeBoundary" ] ''
                                                run mkdir -p "$HOME/.pi/agent/themes"
                                                run cp -f ${
                                                        pkgs.writeText "pi-theme-${self.scheme.name}.json" (
                                                                builtins.toJSON {
                                                                        name = self.scheme.name;
                                                                        colors = self.scheme.pi.colors;
                                                                        export = self.scheme.pi.export;
                                                                }
                                                        )
                                                } "$HOME/.pi/agent/themes/${self.scheme.name}.json"
                                                run chmod 600 "$HOME/.pi/agent/themes/${self.scheme.name}.json"
                                        '';
                                };
                };

        flake.homeManagerModules.pi-coding-agent =
                { pkgs, ... }:
                {
                };

        perSystem =
                { pkgs, ... }:
                {
                };
}
