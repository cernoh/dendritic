{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nixSettings =
    {
      lib,
      ...
    }:
    {
      nix = {
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
          ];
          trusted-users = [
            "root"
            "davr"
          ];
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
    };
}
