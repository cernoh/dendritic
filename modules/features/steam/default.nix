{moduleWithSystem, ...}: {
  flake.nixosModules.steam = moduleWithSystem ({
    pkgs,
    unfreePkgs,
    inputs',
    lib,
    ...
  }: {
    # If buying isn't owning than piracy isn't stealing
    environment.systemPackages = [
      inputs'.sls-steam.packages.default
    ];
    programs.steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
      package = unfreePkgs.steam.override {
        extraEnv = {
          LD_AUDIT = "${
            inputs'.sls-steam.packages.sls-steam
          }/library-inject.so:${
            inputs'.sls-steam.packages.sls-steam
          }/SLSsteam.so";
        };
      };
    };
  });
}
