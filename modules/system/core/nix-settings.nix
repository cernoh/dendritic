{
  inputs,
  ...
}:
let
  # Cachix caches actually consumed by this flake's inputs and features.
  # Deliberately NOT ported from home-manager-v3: `hyprland` (no hyprland
  # feature exists here) and `nixpkgs-wayland` (no overlay pulls from it;
  # all Wayland components come straight from nixpkgs or their own inputs).
  cachixSubstituters = [
    "https://nix-community.cachix.org"
    "https://noctalia.cachix.org"
    # ASAHI-critical: asahi kernel/uboot/mesa builds are far too heavy for
    # local compilation on the Mac.
    "https://nixos-apple-silicon.cachix.org"
    "https://devenv.cachix.org"
    "https://numtide.cachix.org"
    "https://herdr.cachix.org"
  ];
  cachixKeys = [
    # Keys verified against https://app.cachix.org/api/v1/cache/<name>
    # on 2026-08-23.
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    "nixos-apple-silicon.cachix.org-1:8psDu5SA5dAD7qA0zMy5UT292TxeEPzIz8VVEr2Js20="
    "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
    "herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I="
  ];
in
{
  flake.nixosModules.nixSettings =
    { config, ... }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            config.dendritic.userName
          ];
          # cache.nixos.org stays FIRST — substituters are tried in order,
          # and assigning `substituters` replaces the built-in default, so
          # it must be listed explicitly. Without it, user shells whose HM
          # config overrides substituters silently lose the official cache
          # entirely (see managed skill nix-substitution-silently-broken).
          substituters = [ "https://cache.nixos.org" ] ++ cachixSubstituters;
          # Same non-default caches, so untrusted users may use them too.
          trusted-substituters = cachixSubstituters;
          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          ]
          ++ cachixKeys;
        };
        registry.nixpkgs.flake = inputs.nixpkgs;
        nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
        optimise.automatic = true;
        gc = {
          automatic = true;
          dates = "weekly";
          options = "--delete-older-than 14d";
        };
      };

      # Steam, CopilotChat's language server, DaVinci Resolve, ...
      nixpkgs.config.allowUnfree = true;

      # Deliberate deviation from home-manager-v3, which pinned
      # `nix.package = pkgs.nixVersions.latest`: follow the nixpkgs default.
      # nixos-unstable ships a current Nix anyway, and a pin would add a
      # rebuild trigger with no stability benefit.
    };
}
