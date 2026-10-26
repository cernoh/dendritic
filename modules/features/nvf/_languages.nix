{
  languages = {
    enableTreesitter = true;
    enableFormat = true;
    enableDAP = true;
    enableExtraDiagnostics = true;

    nix = {
      enable = true;
      lsp.servers = [ "nil" ];
      # Formatter for conform-nvim (formatOnSave). nvf's nixfmt preset
      # bundles the binary via an absolute store path, so formatting works
      # with nothing on $PATH.
      format.type = [ "nixfmt" ];
    };
    qml.enable = true;
    python = {
      enable = true;
      extraDiagnostics.enable = true;
    };
    css = {
      enable = true;
      format.enable = true;
    };
    dart = {
      enable = true;
      flutter-tools = {
        enable = true;
        color = {
          enable = true;
          virtualText.enable = true;
        };
      };
    };
    kotlin = {
      enable = true;
    };
    lua = {
      enable = true;
      extraDiagnostics.enable = true;
    };

    sql = {
      enable = false;
    };
    typst = {
      enable = true;
      extensions.typst-preview-nvim = {
        enable = true;
      };
    };
    html.enable = true;
    typescript = {
      enable = true;
      lsp.servers = [ "deno" ];
      extensions.ts-error-translator.enable = true;
      format.type = [ "prettier" ];
    };
    json = {
      enable = true;
    };
    rust = {
      enable = true;
      extensions.crates-nvim.enable = true;
      lsp.enable = true;
      lsp.servers = [ "rust-analyzer" ];
      dap.enable = true;
      dap.debugger = [ "lldb" ];
      format.enable = true;
    };
    go = {
      enable = true;
      # LSP is enabled explicitly (like rust above) so gopls does not depend
      # on the global vim.lsp.enable default staying on.
      lsp.enable = true;
      lsp.servers = [ "gopls" ];
    };
    clang.enable = true;
    java = {
      enable = true;
      # nvf's `jls` package (Java debug adapter) cannot build: its pinned
      # maven-deps hash is stale. nvf follows our nixpkgs, and this nixpkgs'
      # maven/openjdk now resolve a different .m2 tree than the one upstream
      # hashed (notashelf/nvf @ 557d2eb, the current main, still carries the
      # old value). jls reaches the closure only through this DAP preset —
      # java completion/diagnostics come from jdt-language-server in nixpkgs
      # and are unaffected — so dropping the DAP drops the broken package.
      # The tree this host resolves is
      # sha256-2HEZClbtiFAWuR8aIgaW1nMl05aI/tShnQFBptamfKQ=: re-enable once
      # nvf ships it (or vendor a jls derivation with that hash).
      dap.enable = false;
    };
    markdown = {
      enable = true;
      extensions.render-markdown-nvim.enable = true;
    };
    svelte = {
      enable = true;
      extraDiagnostics.enable = true;
    };
  };
}
