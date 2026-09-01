# Dojjo feature — workspace manager for jj (Jujutsu).
#
# Upstream: https://github.com/tjarvstrand/dojjo (Dart CLI, no Nix flake).
# Monorepo root is `cli/` (Dart package), so `_dojjo.pkg.nix` builds with
# `src = "${src}/cli"` and vendored `pubspec.lock.json`.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.dojjo ];
# or system-wide:
#   imports = [ self.nixosModules.dojjo ];
#
# Provides `djo` and `dojjo` on PATH (both aliases, via `postInstall`).
# Shell integration is opt-in — add to your shell rc (see `djo shell` docs):
#   eval "$(djo shell init zsh)"    # zsh
#   eval "$(djo shell init bash)"   # bash
#   djo shell init fish | source     # fish
# and completions are installed to
#   share/bash-completion/completions/djo
#   share/zsh/site-functions/_djo
#   share/fish/vendor_completions.d/djo.fish
# via `postInstall` (`djo shell completion …`). We intentionally don't
# auto-inject `eval "$(djo shell init …)"` into `programs.fish`/`bash`/
# `zsh` `interactiveShellInit` to avoid clashing with homeless checkout
# symlinks and to keep the module composable.
#
# `jj` is not pulled in here; add `jujutsu` via `features/programming` or
# `pkgs.jujutsu` if you need the VCS itself.
{
  self,
  inputs,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.dojjo = moduleWithSystem (
    { self', pkgs, ... }:
    {
      environment.systemPackages = [ self'.packages.dojjo ];
    }
  );

  flake.homeManagerModules.dojjo = moduleWithSystem (
    { self', pkgs, ... }:
    {
      home.packages = [ self'.packages.dojjo ];
    }
  );

  perSystem =
    { pkgs, ... }:
    {
      packages.dojjo = pkgs.callPackage ./_dojjo.pkg.nix { src = inputs.dojjo; };
    };
}
