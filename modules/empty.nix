# Skeleton for a dendritic feature module: one file defines a NixOS module
# plus the per-system packages it needs. Rename `name` throughout when
# instantiating. import-tree auto-imports this file — no registration, but a
# parse error here breaks the WHOLE flake.
{
  # This flake itself; used to pull sibling modules by OUTPUT name (see `modules`).
  self,
  # Wraps a NixOS module so its args come from THIS flake's per-system
  # evaluation (overlay-aware `pkgs`, `self'`, `inputs'`) instead of the
  # lower-level NixOS evaluation. Required whenever the module references
  # `self'.packages` or `inputs'.<x>`.
  moduleWithSystem,
  ...
}: {
  # Expose the module as a named output; hosts opt in by adding it to `imports`.
  flake.nixosModules.name = moduleWithSystem ({
    # Args injected by moduleWithSystem, evaluated once per configured system:
    #   pkgs    nixpkgs with this flake's overlays applied
    #   self'   this flake's per-system outputs (e.g. self'.packages.*)
    #   inputs' other inputs' per-system outputs (e.g. inputs'.foo.packages.*)
    pkgs,
    self',
    inputs',
    ...
  }: let
    # Attr-bundle pattern: compose existing modules by output name, never by
    # relative path — import-tree already imports every top-level module.
    modules = with self.nixosModules; [];
  in {
    # Importing IS enabling: own modules need no separate `enable` toggle.
    imports = modules;
    programs.name = {
      enable = true;
      # Use this flake's own build of the program (defined in perSystem below),
      # keeping the system on this flake's nixpkgs/overlays.
      package = self'.packages.hello;
    };
  });
  # Per-system outputs: evaluated once per entry in `flake.systems` (parts.nix).
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    # Usable as `.#hello` on the CLI and as `self'.packages.hello` above.
    packages.hello = pkgs.hello;
  };
}
