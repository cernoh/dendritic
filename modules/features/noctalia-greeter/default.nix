# Noctalia Greeter feature: the greetd login UI matching Noctalia Shell.
#
# System-scoped only — the login screen is a host-level choice, NOT part of
# attrs/desktop. Hosts import flake.nixosModules.noctaliaGreeter and pick
# their session inline, because --session expects that host's compositor's
# desktop-entry Name=:
#   NIXPC: programs.noctalia-greeter.greeter-args = "--session Mango";
#   ASAHI: programs.noctalia-greeter.greeter-args = "--session Niri";
#
# The upstream module (inputs.noctalia-greeter) enables greetd and
# accounts-daemon by default, renders the command as
#   <package>/bin/noctalia-greeter-session -- <greeter-args>
# and asserts default_session.user exists — hence the primary user below
# (dendritic.userName), who is created by system/core (nixosModules.user).
{
  inputs,
  ...
}:
{
  flake.nixosModules.noctaliaGreeter =
    { config, ... }:
    {
      imports = [ inputs.noctalia-greeter.nixosModules.default ];

      programs.noctalia-greeter.enable = true;
      services.greetd.settings.default_session.user = config.dendritic.userName;
    };
}
