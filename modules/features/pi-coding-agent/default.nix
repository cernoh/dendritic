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

          # Herdr resolves an agent kind to ONE hard-coded canonical
          # executable (`herdr agent start --kind pi` types the literal word
          # `pi` into a pane's shell; 0.9.5 has no config key or per-kind
          # command override). So the only place a Pi-Herdr fleet child can be
          # routed to Pi-Bolt is PATH resolution inside that pane — and Herdr
          # panes carry the session PATH, which starts at ~/.local/bin.
          # `agent/bin/pi` is the shim (gated on PI_HERDR_SESSION /
          # PI_HERDR_PI_BOLT, see its header); this link puts it first.
          # Declared here so a fresh checkout reproduces it instead of
          # silently falling back to plain pi children. A store copy, not
          # another out-of-store link: a dangling `~/.local/bin/pi` would
          # break `pi` outright, and the flake source copy only carries
          # tracked files — so forgetting to `git add` it fails the build
          # instead. Changing the shim therefore needs a switch.
          home.file.".local/bin/pi".source = ./home/agent/bin/pi;

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
