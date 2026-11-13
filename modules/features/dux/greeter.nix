# Dux greeter: the greetd login UI that matches the Dux shell. NixOS half
# only — a greeter runs before any user session exists.
#
# Upstream (`inputs.dms-greeter`) publishes `programs.dms-greeter` on
# `nixosModules.default`; `services.displayManager.dux-greeter` never existed,
# and defining it aborts the rebuild with `The option ... does not exist`.
#
# Two facts about the upstream module drive this file:
# - `compositor.name` has no default, so it must be named here. Both hosts run
#   MangoWM, which is also the name upstream resolves the compositor package
#   from (`programs.mango.package`, else `pkgs.mango`).
# - upstream enables greetd itself (`mkDefault` on
#   `services.greetd.settings.default_session.command`), but reads
#   `…default_session.user` — which nothing else sets, and which its own
#   assertions reject when it points at a user that does not exist.
{ self, inputs, ... }:
{
  flake.nixosModules.dms-greeter =
    { config, ... }:
    {
      imports = [ inputs.dms-greeter.nixosModules.default ];

      programs.dms-greeter = {
        enable = true;
        compositor.name = "mango";
      };

      services.greetd.settings.default_session.user = config.dendritic.userName;
    };
}
