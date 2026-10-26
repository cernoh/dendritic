{
  description = "Dendritic master flake.";

  # Offered by every `nix` command run against this flake; consumers accept
  # once and get correct caches regardless of a broken global client
  # ~/.config/nix/nix.conf (handoff: binary-cache substitution). Mirrors
  # modules/system/core/nix-settings.nix; keep both lists in sync.
  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      "https://nixos-apple-silicon.cachix.org"
      "https://devenv.cachix.org"
      "https://numtide.cachix.org"
      "https://herdr.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
      "herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Must follow nixpkgs: apple-silicon-support modules inject packages
    # (alsa-ucm-conf-asahi, ...) into host configs. Without the follow they
    # come from the input's own eval-system nixpkgs and break aarch64 hosts
    # evaluated from any other machine (issue #16).
    asahi = {
      url = "github:tpwrules/nixos-apple-silicon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Must NOT follow nixpkgs (issue #179): upstream builds the shell and the
    # greeter against its own locked nixpkgs and publishes them to
    # noctalia.cachix.org. A follow changes every store path in those builds,
    # so Nix substitutes nothing and compiles both packages from source. Only
    # the packages cross the boundary — the modules take `pkgs` from the host
    # eval.
    # The shell tracks the `cachix` branch, which always points at the newest
    # commit CI has already cached (noctalia-docs, binary cache). The greeter
    # has no such branch; upstream caches its main-branch builds, so a bump to
    # a commit CI has not built yet costs one local build.
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
    };
    # Pinned rev (v0.2.2), flake = false: consumed as source for the Dart AOT
    # fallback in modules/features/dojjo/_dojjo.pkg.nix (unsupported systems) and
    # for pinning the binary release.
    dojjo = {
      url = "github:tjarvstrand/dojjo/v0.2.2";
      flake = false;
    };
    # Pinned tag (v2.0.1), flake = false: consumed as a plain source tree by the
    # cursor build in modules/features/retrosmart-cursor/_retrosmart-cursor.pkg.nix.
    # URL form, not git+https, on purpose: this host's Nix cannot fetch a
    # git+https input (its git transport fails even for github.com). Only the
    # unpacked source tree crosses the boundary; the input carries no flake.
    #
    # 2026-10-13 (btrfs migration, issue #274): this URL pointed at a
    # third-party mirror, github.laiyagushi.com, which is now NXDOMAIN and
    # cannot be fetched at all. It silently blocked every fresh nixos-install
    # from this flake. The upstream tag archive is byte-identical (same
    # narHash sha256-zZwxtdFlxYUNbyGtC8nNWqrvS9DW1H+2YOYr7LdcEVU=), so the URL
    # moved back to github.com and flake.lock needed no change.
    retrosmart-cursor = {
      url = "https://github.com/useless-anvil/retrosmart-cursor/archive/refs/tags/v2.0.1.tar.gz";
      flake = false;
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # GTK/Qt theming (issue #164). Follows nixpkgs, because stylix themes the
    # GTK and Qt packages of the evaluated system and refuses to mix package
    # sets.
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    wrappers.url = "github:BirdeeHub/nix-wrapper-modules";
    qmd = {
      url = "github:tobi/qmd";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Declarative Flatpaks (modules/features/flatpak). `latest` tracks the
    # newest stable nix-flatpak release; applications remain host-owned data.
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/latest";
    };
    # Machine-quirk profiles (modules/system/hardware-profiles). Follows
    # nixpkgs: every profile is a plain NixOS module that reads the host's
    # `pkgs`/`lib`, so a non-followed copy would evaluate against a second
    # nixpkgs and duplicate store paths. A host opts in by naming profiles in
    # its `_hardware-profiles-settings.nix`; see that module's coverage matrix.
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
