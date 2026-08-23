{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nvidiaDrivers =
    {
      pkgs,
      ...
    }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      environment.systemPackages = with pkgs; [
        vulkan-tools
      ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;
          powerManagement.enable = true;
          open = true;
          nvidiaSettings = true;
        };
      };
    };
}
