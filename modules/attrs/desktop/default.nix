# Shared desktop-machine base: core system + networking + audio + removable
# media handling + home-manager features + act (local GitHub Actions runner,
# pulls in the docker runtime).
#
# Plain nixosModule (not moduleWithSystem) on purpose: its `pkgs` argument is
# the NixOS *configured* system pkgs, so package selections below honour
# `nixpkgs.config` (e.g. allowUnfree). moduleWithSystem's `pkgs` is the raw
# flake-parts perSystem pkgs, which would evaluate unfree packages (obsidian)
# against an unconfigured set and trip the unfree-license refusal.
# herdr 0.9.1 fails to link with binutils 2.46: the zig-built static
# libghostty-vt leaves overlapping FDEs in .eh_frame, and ld.bfd treats that as
# fatal (".eh_frame_hdr refers to overlapping FDEs"). lld merges them, so the
# Rust link step goes through lld. NIX_RUSTFLAGS, not RUSTFLAGS: the nixpkgs
# rustc wrapper appends only NIX_RUSTFLAGS to every rustc call, and RUSTFLAGS is
# consumed by cargo (build scripts only). Drop this overlay when nixpkgs ships
# a herdr that links (or upstream stops shipping the zig static lib).
{
  self,
  ...
}:
{
  flake.overlays.herdr = final: prev: {
    herdr = prev.herdr.overrideAttrs (o: {
      nativeBuildInputs = o.nativeBuildInputs ++ [ final.lld ];
      env = (o.env or { }) // {
        NIX_RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
      };
    });
  };

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
        computerUse
        stylix
        nautilus
      ];

      # Allow unfree packages (e.g. obsidian) on every desktop host — NIXPC
      # and ASAHI both import this module. Without this the pure CI eval
      # refuses unfree licenses during system.build.toplevel evaluation.
      nixpkgs.config.allowUnfree = true;

      # herdr is built here (systemPackages below) and by the herdr-web bridge
      # PATH, so the link fix has to be in place before those are evaluated.
      nixpkgs.overlays = [ self.overlays.herdr ];

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
