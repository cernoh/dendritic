# Computer-use toolchain: observe and drive a Wayland session from the shell.
# This covers agent GUI work (screenshot plus vision loops, scripted input) as
# well as manual screen capture (issue #146).
#
# One concern per feature dir. NixOS-scoped: every process in the session can
# use these binaries, and both hosts run a wlroots-based Wayland desktop
# (NIXPC mango, ASAHI niri).
#
# Included:
#   grim          wlroots screencopy — whole-layout, per-output, and region PNG
#   slurp         region picker for `grim -g "$(slurp)"`
#   wayland-utils wayland-info: which protocols the compositor really exposes
#   wlr-randr     output geometry and EDID ground truth
#   wlrctl        pointer injection plus foreign-toplevel control
#   wtype         keyboard injection via zwp_virtual_keyboard_manager_v1
#
# Deliberately absent:
#   - wl-clipboard: NIXPC gets wl-clipboard-rs through `mango`, ASAHI gets the
#     C wl-clipboard through the `clipboard` HM feature. A third copy here
#     would collide on wl-copy/wl-paste inside the system profile.
#   - ydotool: it needs write access to /dev/uinput, which is root-only here.
#   - xdotool / wmctrl: X11 only, useless under Wayland.
#
# `mango` also installs grim and slurp for its screenshot bindings. The
# duplicate is the same derivation, so buildEnv de-duplicates by store path.
#
# Opt in from a host: imports = [ self.nixosModules.computerUse ];
# attrs/desktop imports it, so both hosts get it.
{ ... }:
{
  flake.nixosModules.computerUse =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [
        grim
        slurp
        wayland-utils
        wlr-randr
        wlrctl
        wtype
      ];
    };
}
