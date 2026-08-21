{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.audio = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = with pkgs; [
      playerctl
      pavucontrol
      pulseaudioFull
    ];
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    nixpkgs.config.pulseaudio = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
