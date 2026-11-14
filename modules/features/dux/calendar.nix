# Dux calendar (dank-calendar). Home-manager half only.
#
# Upstream (`inputs.dcalendar`) publishes `programs.dank-calendar` on both
# `nixosModules.default` and `homeModules.default`, and both halves define the
# same `dcal.service` user unit — importing both would install it twice. The HM
# half is the one kept: it is the half that can bind the unit to the
# compositor's `wayland.systemd.target` and write `~/.config/dankcal/…` for the
# session that is actually running.
{ self, inputs, ... }:
{
  flake.homeManagerModules.dcalendar = {
    imports = [ inputs.dcalendar.homeModules.default ];

    programs.dank-calendar = {
      enable = true;
      systemd.enable = true;
    };
  };
}
