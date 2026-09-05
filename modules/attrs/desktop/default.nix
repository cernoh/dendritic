# Shared desktop-machine base: core system + networking + audio + removable
# media handling + home-manager features + act (local GitHub Actions runner,
# pulls in the docker runtime).
#
# Plain nixosModule (not moduleWithSystem) on purpose: its `pkgs` argument is
# the NixOS *configured* system pkgs, so package selections below honour
# `nixpkgs.config` (e.g. allowUnfree). moduleWithSystem's `pkgs` is the raw
# flake-parts perSystem pkgs, which would evaluate unfree packages (obsidian)
# against an unconfigured set and trip the unfree-license refusal.
{
  self,
  ...
}:
{
  flake.nixosModules.desktop =
    {
      pkgs,
      ...
    }:
    {
      imports = with self.nixosModules; [
        core
        network
        audio
        homeManager
        act
        waylandBase
      ];

      # Allow unfree packages (e.g. obsidian) on every desktop host — NIXPC
      # and ASAHI both import this module. Without this the pure CI eval
      # refuses unfree licenses during system.build.toplevel evaluation.
      nixpkgs.config.allowUnfree = true;
      # System fonts for every desktop host (NIXPC + ASAHI both import this
      # module): Droid Sans Mono is ghostty's active family
      # (features/ghostty/config); Monofur rides along for editor/UI use.
      fonts.packages = with pkgs.nerd-fonts; [
        droid-sans-mono
        monofur
      ];

      # CLI tooling shared by every desktop host (NIXPC + ASAHI both import
      # this module). Excludes programming languages and language servers:
      # runtimes (jdk/lua/python3/nodejs/deno/bun) are brought per-project via
      # direnv (see features/programming), and LSPs (nixd, lua-language-server)
      # are bundled inside the nvf editor feature. `docker` is intentionally
      # omitted here — the `act` module above already pulls in the docker
      # feature (daemon + CLI) on both hosts.
      environment.systemPackages = with pkgs; [
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
    };
}
