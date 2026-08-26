# Shared desktop-machine base: core system + networking + audio + removable
# media handling + home-manager features + act (local GitHub Actions runner,
# pulls in the docker runtime).
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.desktop = moduleWithSystem (
    {
      pkgs,
      ...
    }:
    let
      modules = with self.nixosModules; [
        core
        network
        audio
        usbAutomount
        homeManager
        act
      ];

      # CLI tooling shared by every desktop host (NIXPC + ASAHI both import
      # this module). Excludes programming languages and language servers:
      # runtimes (jdk/lua/python3/nodejs/deno/bun) are brought per-project via
      # direnv (see features/programming), and LSPs (nixd, lua-language-server)
      # are bundled inside the nvf editor feature. `docker` is intentionally
      # omitted here — the `act` module above already pulls in the docker
      # feature (daemon + CLI) on both hosts.
      desktopTools = with pkgs; [
        p7zip
        nixfmt
        inotify-tools
        fastfetch
        tailscale
        tree-sitter
        worktrunk
        act
        cloudflared
        stylua
        maven
        lldb
        clang
        opencode
        herdr
        yazi
        pinentry-curses
        cachix
        git
        lazygit
        jujutsu
        vim
        pandoc
        texliveFull
        bzip2
        devbox
        yarn
        ripgrep
        fd
        jq
        htop
        curl
        wget
        bitwarden-cli
        tree
        eza
        zoxide
        bat
        tmux
        fzf
        bottom
        unzip
        obsidian
        ffmpeg_6
        yt-dlp
        tealdeer
        exiftool
        ncspot
        typst
        nushell
        devenv
      ];
    in
    {
      imports = modules;

      environment.systemPackages = desktopTools;
    }
  );
}
