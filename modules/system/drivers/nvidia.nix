{...}: {
  flake.nixosModules.nvidiaDrivers = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      mesa
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
      };
      open = true;
      nvidiaSettings = true;
    };

    boot.kernelParams = [
      "amdgpu.ppfeaturemask=0xffffffff"
    ];

    # For rOCM
    systemd.tmpfiles.rules = [
      "L+ /opt/rocm - - - - ${pkgs.rocmPackages.clr}"
    ];
  };
}
