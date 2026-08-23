{ moduleWithSystem, ... }: {
  flake.nixosModules.steam = moduleWithSystem (
    {
      pkgs,
      ...
    }:
    {
      # NOTE: upstream voidarc injects the SLSsteam library here via an
      # `sls-steam` flake input; this flake does not carry that input, so the
      # stock package is used.
      programs.steam = {
        enable = true;
        protontricks.enable = true;
        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };
    }
  );
}
