{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.user =
    {
      pkgs,
      lib,
      ...
    }:
    let
      userName = "davr";
    in
    {
      programs.fish.enable = true;

      users.users.${userName} = {
        isNormalUser = true;
        description = userName;
        shell = pkgs.fish;
        # Bootstrap credential for first login only; replace afterwards:
        #   passwd  (stores a hash instead of this initial value)
        initialPassword = "changeme";
        extraGroups = [
          "wheel"
          "networkmanager"
          "audio"
          "video"
          "input"
        ];
      };
    };
}
