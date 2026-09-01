# Dojjo feature — workspace manager for jj (Jujutsu).
#
# Upstream: https://github.com/tjarvstrand/dojjo (Dart CLI, no Nix flake).
# Release artifacts are AOT Dart binaries published per tag; this feature
# vendors the binaries via _dojjo.pkg.nix (fetchurl) instead of building
# from Dart source — the install.sh does the same curl to GitHub releases.
# Alternative considered: buildDartApplication from the `cli/` subdir. That
# would cover aarch64-linux (no prebuilt) but needs a vendored pub cache
# hash and drags the Dart SDK into the rebuild; the release artifact is
# upstream's intended distribution and keeps the closure minimal.
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.dojjo ];
# or system-wide:
#   imports = [ self.nixosModules.dojjo ];
#
# Provides `djo` (and `dojjo` symlink) on PATH. Shell integration for
# `switch`/`merge` cd-wrapping is wired automatically when the corresponding
# shell module is enabled — matching `djo shell init <shell>` / `djo shell
# completion <shell>` docs:
#   eval "$(djo shell init zsh)"    # zsh
#   eval "$(djo shell init bash)"   # bash
#   djo shell init fish | source     # fish
#
#jj is not pulled in here; add `jujutsu` via features/programming or
#pkgs.jujutsu if you need the VCS itself. Config lives in worktrunk-
#compatible TOML (see https://github.com/tjarvstrand/dojjo#configuration).
{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.dojjo =
    {
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.dojjo
      ];
    };

  flake.homeManagerModules.dojjo =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      home.packages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.dojjo
      ];

      # Shell integration: cd wrapping for `djo switch` / `djo merge`.
      # Guarded so the module composes cleanly whether or not the host
      # enables fish/bash/zsh (homeless-dotfiles friendly — no generated
      # config file, just shell init).
      programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
        if type -q djo
          djo shell init fish | source
        end
      '';

      programs.bash.initExtra = lib.mkIf config.programs.bash.enable ''
        if command -v djo >/dev/null 2>&1; then
          eval "$(djo shell init bash)"
        fi
      '';

      programs.zsh.initExtra = lib.mkIf config.programs.zsh.enable ''
        if command -v djo >/dev/null 2>&1; then
          eval "$(djo shell init zsh)"
        fi
      '';

      # Optional: tab completion (uncomment if desired, or run manually:
      #   djo shell completion <shell> | source
      # Keeping it off by default avoids double-eval for users who prefer
      # explicit completion wiring.
      # programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
      #   djo shell completion fish | source
      # '';
    };

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.dojjo = pkgs.callPackage ./_dojjo.pkg.nix { src = inputs.dojjo; };
    };
}
