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
    davinci = {
      url = "git+https://git.voidarc.co.uk/voidarc/nixos.davinci";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned rev (v0.2.2), flake = false: consumed as source for the Dart AOT
    # fallback in modules/features/dojjo/_dojjo.pkg.nix (unsupported systems) and
    # for pinning the binary release.
    dojjo = {
      url = "github:tjarvstrand/dojjo/v0.2.2";
      flake = false;
    };
    # Pinned rev (v4.8.0), flake = false: consumed as a plain source tree by
    # the data package in modules/features/stremio-kai/_stremio-kai.pkg.nix.
    stremio-kai = {
      url = "github:allecsc/Stremio-Kai/37e6273a7d18ff0a3745c59265aebd99bb2509a6";
      flake = false;
    };
    # Pinned rev, flake = false: consumed as a plain source tree by the Mirai
    # Miracast package in modules/features/noctalia/_mirai.pkg.nix. The input is
    # not followed by nixpkgs because it carries none — only the source tree
    # crosses the boundary. Upstream publishes no tags, so the rev is pinned.
    mirai = {
      url = "github:Leriart/Mirai/1e7148b392107eec748b0213ef65c23f62fdfc1e";
      flake = false;
    };
    # Pinned tag (v2.0.1), flake = false: consumed as a plain source tree by the
    # cursor build in modules/features/retrosmart-cursor/_retrosmart-cursor.pkg.nix.
    # The fork lives off github.com, so the URL is spelled out; the URL form is
    # the tag archive, because this host's Nix cannot fetch a git+https input
    # (its git transport fails even for github.com). The input carries no flake;
    # only its XPM artwork and build scripts cross the boundary.
    retrosmart-cursor = {
      url = "https://github.laiyagushi.com/useless-anvil/retrosmart-cursor/archive/refs/tags/v2.0.1.tar.gz";
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
  };
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
