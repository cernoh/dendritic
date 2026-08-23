# Oh My Pi (omp) feature, ported from ~/.config/home-manager-v3.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.omp ];
#
# The `omp-flake` input provides the binary and the programs.oh-my-pi
# options; this module enables it and wires the state directory the way
# home-manager-v3 does: `~/.omp` is an out-of-store symlink into THIS
# repo checkout, so omp reads tracked config and writes runtime state
# (dbs, sessions, logs) in place — editable live, never in the store.
# Tracked content lives in ./home (see its .gitignore for what stays out).
{ inputs, ... }: {
  # Home-manager feature module. Import IS enabling.
  flake.homeManagerModules.omp =
    {
      config,
      ...
    }:
    {
      # Provides the programs.oh-my-pi options and installs the omp package.
      imports = [ inputs.omp-flake.homeManagerModules.default ];

      programs.oh-my-pi.enable = true;

      # Out-of-store symlink: must point at a stable writable checkout, not a
      # store path (omp mutates ~/.omp constantly). Same mechanism as
      # home-manager-v3/home.nix, retargeted at this flake's location.
      home.file.".omp".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/omp/home";
    };

  # Raw upstream omp build per system (`.#omp` / `nix run .#omp`). The HM
  # module above already installs the same package via programs.oh-my-pi.
  perSystem = { inputs', ... }: {
    packages.omp = inputs'.omp-flake.packages.default;
  };
}
