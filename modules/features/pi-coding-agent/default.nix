{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.pi-coding-agent =
    {
      pkgs,
      config,
      ...
    }:
    {
      environment.systemPackages = [
        pkgs.pi-coding-agent
        pkgs.nodejs
        self.packages.${pkgs.stdenv.hostPlatform.system}.qmd
      ];

      home-manager.users.${config.dendritic.userName} =
        { config, ... }:
        {
          # Out-of-store symlink into this checkout
          home.file.".pi".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/pi-coding-agent/home";
        };
    };

  flake.homeManagerModules.pi-coding-agent =
    { pkgs, ... }:
    {
      home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.qmd ];
    };

  perSystem =
    { pkgs, ... }:
    {
      packages.qmd = inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
}
