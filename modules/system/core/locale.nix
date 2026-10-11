{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.locale =
    {
      pkgs,
      lib,
      ...
    }:
    {
      time.timeZone = "Europe/London";
      i18n = {
        defaultLocale = "en_GB.UTF-8";
        extraLocaleSettings = {
          LC_ADDRESS = "en_GB.UTF-8";
          LC_IDENTIFICATION = "en_GB.UTF-8";
          LC_MEASUREMENT = "en_GB.UTF-8";
          LC_MONETARY = "en_GB.UTF-8";
          LC_NAME = "en_GB.UTF-8";
          LC_NUMERIC = "en_GB.UTF-8";
          LC_PAPER = "en_GB.UTF-8";
          LC_TELEPHONE = "en_GB.UTF-8";
          LC_TIME = "en_GB.UTF-8";
        };
      };
      # mkDefault, not a plain value: `layout` and `keyMap` are single strings,
      # so a host picking a different keyboard (ASAHI uses a US Apple keyboard)
      # overrides these by normal priority instead of colliding.
      services.xserver.xkb = {
        layout = lib.mkDefault "gb";
        variant = lib.mkDefault "";
      };
      console.keyMap = lib.mkDefault "uk";
    };
}
