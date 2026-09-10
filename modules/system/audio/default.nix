{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.audio =
    {
      pkgs,
      lib,
      ...
    }:
    {
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

        # The AB13X headset adapter (001f:0b21) is the NIXPC default sink. Its
        # only mixer control is "PCM Playback Switch", and that control carries
        # the INV_BOOLEAN flag. WirePlumber writes the switch, the device
        # reports the change, WirePlumber stores the route properties and
        # applies the route again: the sink mute state then toggles at 5-10 Hz
        # and the audio cuts in and out (issue #156). Force software mute and
        # software volume for this card, so the broken switch stays untouched.
        # The match is by card name, so other cards keep their hardware mixer.
        wireplumber.extraConfig."51-usb-audio-soft-mixer" = {
          "monitor.alsa.rules" = [
            {
              matches = [ { "device.name" = "~alsa_card.usb-Generic_USB_Audio.*"; } ];
              actions."update-props"."api.alsa.soft-mixer" = true;
            }
          ];
        };
      };
    };
}
