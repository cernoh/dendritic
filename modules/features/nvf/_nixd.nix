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
      #
      # NOTE: unlike the source config this was ported from, there are no
      # hardcoded `options.*.expr` entries here: those pointed at host
      # names of the old home-manager-v3 flake (asahi, debian, nixwsl,
      # darwin) that do not exist in a consuming flake. Re-add per-host
      # labels once hosts are defined, e.g.:
      #   options.dendritic.expr =
      #     "(builtins.getFlake (toString ./.)).nixosConfigurations.<host>.options";
      nixpkgs = {
        expr = "import (builtins.getFlake (toString ./.)).inputs.nixpkgs { }";
      };

      # Formatting is deliberately NOT configured here: nvf owns it via
      # vim.languages.nix.format.type (conform-nvim, bundled nixfmt preset
      # with an absolute store path). Pointing nixd at a bare `formatting.
      # command` would reintroduce a $PATH dependency that breaks in any
      # environment without a globally installed formatter.
    };
  };
}
