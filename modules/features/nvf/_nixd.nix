# nixd LSP server configuration.
#
# nixd is the Nix language server. It reads its configuration via
# the LSP `workspace/configuration` channel under the `nixd` key.
# nvf feeds `vim.lsp.servers.<name>` to Neovim 0.11's `vim.lsp.config()`,
# so anything we put in `settings` here is forwarded verbatim. The
# submodule for `vim.lsp.servers.<name>` has `freeformType =
# attrsOf anything`, which is what makes this pass-through work.
#
# Reference: https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
#
# Fields populated below:
#   nixpkgs     - the nixpkgs instance nixd uses for package/lib completion
#   options     - the module systems nixd completes option paths for
#
# The launch command is not here: ./default.nix sets it, because nixd needs the
# store path of its package and the `--semantic-tokens=true` flag that turns on
# the experimental attrname/select colouring. `pkgs` and `lib` are in scope
# there, not in this data file.
#
# `hostName` is the flake attribute name of the host whose configuration this
# editor runs on (`NIXPC`, `ASAHI`), and `userName` is that host's home-manager
# user (`davr`, `da`). The option sets are read from
# `nixosConfigurations.<hostName>`, so they carry every option this flake's
# inputs contribute.
{ hostName, userName }:
{
  # Root markers that tell nixd where the workspace root lives.
  # The nvf nixd preset ships with `[ ".git" ]`; we also accept
  # `flake.nix` so that nixd anchors on the flake root even when
  # editing a file outside any git working tree.
  root_markers = [
    "flake.nix"
    ".git"
  ];

  # This is the table nixd consumes. The outer `nixd` key is the
  # LSP-namespace convention - nixd ignores everything else at the
  # `settings` level.
  settings = {
    nixd = {
      # Pin nixpkgs to the edited project's flake input. This keeps LSP
      # completion aligned with what `nix build` would actually evaluate,
      # and avoids drift from the system `<nixpkgs>`.
      #
      # The `import (flake) { }` form delegates system detection to
      # the nixpkgs flake itself, so the same expression works on
      # x86_64-linux, aarch64-linux, and aarch64-darwin without
      # needing a per-host string.
      nixpkgs = {
        expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }";
      };

      # Option-path completion. Each entry names an option system and gives
      # the expression that evaluates to its declarations; nixd merges the
      # entries, so a module edit sees every option at once.
      #
      # `nixos` and `home-manager` both read the evaluated host, which is what
      # makes the flake's inputs visible to completion: the host imports nvf,
      # home-manager, stylix, asahi, mango, and the rest, so their options are
      # part of `nixosConfigurations.<hostName>.options`.
      #
      # Home manager's tree comes from the exported `dendritic.nixdOptionTree`
      # of the user's submodule (system/home-manager), not from the expression
      # nixd's documentation suggests
      # (`...options.home-manager.users.type.getSubOptions []`): that one reads
      # the submodule *type*, which holds the shared modules alone, so it has no
      # `programs.nvf`, `programs.omp`, or `stylix`. Measured on this flake.
      options = {
        nixos = {
          expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.${hostName}.options";
        };
        home-manager = {
          expr = "(builtins.getFlake (toString ./.)).nixosConfigurations.${hostName}.config.home-manager.users.${userName}.dendritic.nixdOptionTree";
        };
        # `debug` and `currentSystem` exist because `modules/parts.nix` sets
        # `debug = true`; `currentSystem` is the per-system tree, which is where
        # `perSystem.packages.*` and friends live.
        flake-parts = {
          expr = "let f = builtins.getFlake (toString ./.); in f.debug.options // f.currentSystem.options";
        };
      };

      # Formatting is deliberately NOT configured here: nvf owns it via
      # vim.languages.nix.format.type (conform-nvim, bundled nixfmt preset
      # with an absolute store path). Pointing nixd at a bare `formatting.
      # command` would reintroduce a $PATH dependency that breaks in any
      # environment without a globally installed formatter.
    };
  };
}
