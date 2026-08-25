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
      config,
      ...
    }:
    let
      userName = config.dendritic.userName;
    in
    {
      options.dendritic.userName = lib.mkOption {
        type = lib.types.str;
        default = "davr";
        description = ''
          Login name of this machine's primary human user. Modules that mean
          "the primary user" read this instead of hardcoding a name; hosts
          with a different login override it (ASAHI sets "da").
        '';
      };

      config = {
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
    };
}
