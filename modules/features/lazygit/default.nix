{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.lazygit =
    {
      pkgs,
      lib,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        self.packages.${pkgs.stdenv.hostPlatform.system}.lazygit
      ];
    };
  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    let
      config-file = pkgs.writeText "config.yml" ''
        gui:
          nerdFontsVersion: "3"

        customCommands:
          - key: 'p'
            context: 'global'
            command: 'git pull --recurse-submodules'
            loadingText: 'Pulling with submodules'
            output: 'log'
          - key: '<c-p>'
            context: 'global'
            command: 'git pull'
            loadingText: 'Pulling remote repo'
            output: 'log'
      '';
    in
    {
      packages.lazygit = inputs.wrappers.lib.wrapPackage (
        {
          config,
          wlib,
          lib,
          ...
        }:
        {
          inherit pkgs;
          package = pkgs.lazygit;
          flags = {
            "--use-config-file" = config-file;
          };
        }
      );
    };
}
