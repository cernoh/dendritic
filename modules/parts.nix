{ lib, ... }: {
  config.systems = [
    "x86_64-linux"
    "x86_64-darwin"
    "aarch64-linux"
    "aarch64-darwin"
  ];

  # flake-parts predeclares mergeable options for NixOS-flavored outputs
  # (flake.nixosModules etc.) but NOT home-manager ones. An undeclared
  # output attr gets a unique, non-mergeable option, so two files that each
  # define `flake.homeManagerModules.<name>` collide with "defined multiple
  # times". Declaring it makes HM feature modules composable across files.
  options.flake.homeManagerModules = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
  };

  config.perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;
    };
}
