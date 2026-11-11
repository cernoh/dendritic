# Dux suite bundle: shell, greeter, search and calendar from the duxlabs-dev
# forks (DMS = "Dux Modular Shell"). Replacement for the `noctalia` +
# `noctaliaGreeter` pair both hosts used to import.
#
# Which half each feature lands on follows from where upstream publishes its
# module (see each feature's header): the shell, search and calendar are
# user-session features and are exported on the home-manager half only, while
# the greeter runs before any session exists and is the one NixOS-side import.
#
# This module also owns the shell's compositor keys. They are NOT in
# `features/mango`: the compositor feature must not name an application, so it
# opens its `bind` list through `dendritic.mango.extraBinds` and each shell
# advertises its own keys. Importing `dux` is therefore also what claims
# SUPER+D, SUPER+SHIFT+S, CTRL+Print and ALT+Print — a host that imports the
# shell feature without `mango` cannot set those options at all, and every key
# here is exclusive (a duplicate fails `mango -c -p`, i.e. the build).
{ self, ... }:
{
  flake.nixosModules.dux =
    { config, lib, pkgs, ... }:
    let
      # Store path, not a bare `dms`. A mango bind runs through `spawn_shell`,
      # whose PATH is whatever the session inherited — and the shell's own
      # binary is installed per-user, so PATH is the one handle that can go
      # stale on the compositor side.
      dmsBin = lib.getExe config.programs.dank-material-shell.package;
    in
    {
      imports = with self.nixosModules; [
        dms
        dms-greeter
      ];

      # Qt5 compatibility shim required by the DMS clight widget and other
      # Qt5-era QML imports pulled in by dux plugins.
      environment.systemPackages = [ pkgs.qt6.qt5compat ];

      # Mapped from the Noctalia binds these replace: `panel-open launcher` →
      # the DMS launcher, `screenshot-region|fullscreen|window` → `dms
      # screenshot region|full|window` (`full` is the focused output, which is
      # what the old fullscreen key captured).
      #
      # The old SUPER+SHIFT+T toggled Noctalia's `cernoh/terminal` dropdown
      # panel. DMS has no dropdown terminal — its only `scratchpad` IPC target
      # is Hyprland-gated — so that key was dropped instead of bound to
      # something that is not a terminal; SUPER+T still spawns $TERMINAL.
      dendritic.mango.extraBinds = [
        "SUPER,D,spawn_shell,${dmsBin} ipc call launcher toggle"
        "SUPER+SHIFT,S,spawn_shell,${dmsBin} screenshot region"
        "CTRL,Print,spawn_shell,${dmsBin} screenshot full"
        "ALT,Print,spawn_shell,${dmsBin} screenshot window"
      ];
    };

  flake.homeManagerModules.dux = { pkgs, ... }: {
    imports = with self.homeManagerModules; [
      dms
      dsearch
      dcalendar
    ];

    home.packages = [ pkgs.qt6.qt5compat ];
  };
}
