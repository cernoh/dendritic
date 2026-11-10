# <name> feature — <one line: what it installs or configures>.
#
# Copy this directory to `features/<name>`. The leading `_` is why `import-tree`
# skips it, so the rename is the only step that puts the feature in the flake.
# Then:
#
#   1. Replace `<name>` (the export names, the `name` binding, and the file
#      names below must agree) and delete the half you do not need.
#   2. Add `self.homeManagerModules.<name>` and/or `self.nixosModules.<name>` to
#      the host, bundle, or `modules/attrs/*` set that should have it. Import IS
#      enabling — there is no `enable` option (`../AGENTS.md`).
#   3. Add the name to the Feature table in `../AGENTS.md`. Add a Child DOX
#      Index line only if this directory owns contracts of its own — most
#      features carry no AGENTS.md at all.
#
# Companions that belong beside this file:
#
#   `_<name>.pkg.nix`  a derivation from a pinned flake input. The `_` prefix
#                      keeps `import-tree` from reading it as a module; the
#                      feature imports it explicitly and exposes it per system:
#
#                        perSystem = { pkgs, ... }: {
#                          packages.<name> = import ./_<name>.pkg.nix {
#                            inherit pkgs;
#                            src = inputs.<input>;
#                          };
#                        };
#
#   `home/`            live-editable config, reached through an out-of-store
#                      symlink rather than copied into the store.
#
# A feature that behaves differently per machine declares `dendritic.<name>.*`
# options and reads them from `hosts/<HOST>/_<name>-settings.nix`; the `mango`
# entry in `../AGENTS.md` is the reference.
{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
let
  # The single definition of the name: exports, option prefixes, and any
  # `~/.config/<name>` path read it.
  name = "<name>";
in
{
  # Home-manager half: dotfiles, `programs.*`, user services. Delete this block
  # for a system-only feature.
  flake.homeManagerModules.${name} =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      # TODO: the feature itself, e.g.
      #   home.packages = [ pkgs.<package> ];
      #   xdg.configFile."<app>/config".source = ./home;
      #
      # Config the user edits must stay in the checkout, so it is a symlink,
      # not store content:
      #   xdg.configFile."<app>".source =
      #     config.lib.file.mkOutOfStoreSymlink
      #       "${self}/modules/features/${name}/home";
    };

  # NixOS half: daemons, `environment.systemPackages`, system options. Delete
  # this block for a user-level feature. `moduleWithSystem` is how a NixOS
  # module reaches this repo's own per-system packages (`self'.packages`).
  flake.nixosModules.${name} = moduleWithSystem (
    { self', pkgs, ... }:
    {
      # TODO: system wiring, e.g.
      #   environment.systemPackages = [ self'.packages.${name} ];
      #
      # A user service carries an explicit PATH — systemd's compiled-in search
      # path has no /run/current-system/sw/bin:
      #   systemd.user.services.${name} = {
      #     path = with pkgs; [ git curl coreutils ];
      #     serviceConfig.ExecStart = "${self'.packages.${name}}/bin/<name>";
      #     wantedBy = [ "default.target" ];
      #   };
      #
      # To reach the home-manager half from here, so that this import is the
      # whole enable switch (the `wayfinder-dashboard` pattern):
      #   home-manager.sharedModules = [ self.homeManagerModules.${name} ];
    }
  );
}
