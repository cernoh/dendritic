{
  languages = {
    enableTreesitter = true;
    enableFormat = true;
    enableDAP = true;

    nix = {
      enable = true;
      extraDiagnostics.enable = true;
      lsp.servers = ["nixd"];
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
    lua = {
      enable = true;
      extraDiagnostics.enable = true;
    };

    sql = {
      enable = true;
      extraDiagnostics.enable = true;
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
      lsp.servers = ["deno"];
      extensions.ts-error-translator.enable = true;
      format.type = ["prettier"];
    };
    json = {
      enable = true;
    };
    rust = {
      enable = true;
      extensions.crates-nvim.enable = true;
      lsp.enable = true;
      dap.enable = true;
      dap.debugger = ["lldb"];
      format.enable = true;
    };
    go.enable = true;
    clang.enable = true;
    java.enable = true;
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
