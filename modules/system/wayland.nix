# Wayland + XWayland desktop stack for every MangoWM host.
#
# Two jobs, deliberately kept in one module because they are the same problem
# seen from two sides: making native Wayland clients and X11 clients (through
# XWayland) behave like one desktop instead of two half-configured ones.
#
#   1. The tooling to see and fix what each side is doing. Most of this is
#      command-line software, installed system-wide so it is on PATH for
#      `sudo`-free debugging from any shell or TTY. It is *packaged*, not
#      autostarted: nothing here changes behaviour until it is run.
#   2. The two services that have to be running for the desktop to be usable:
#      a polkit authentication agent and the GNOME keyring. These are the
#      "keychain" half — without an agent, a GUI app that asks polkit for
#      anything (mount a drive, change a network) silently fails; with one, you
#      get a prompt and polkit remembers the answer for the session.
#
# Deliberately standalone: this module ships the full toolkit even where a
# feature (mango, computer-use, clipboard) already installs part of it. A
# duplicated package in two store paths is cheap; a desktop whose debugging
# tools are only present when some unrelated feature happens to be enabled is
# not. Do not "deduplicate" this file against features — it is intentionally
# self-sufficient.
#
# Portals: the portal stack (file choosers, settings, screencast) comes from
# `portals`, imported here so BOTH hosts get it. Mango is a wlroots
# compositor, so `xdg-desktop-portal-wlr` is the screencast/screenshot
# backend that actually works on both machines.
#
# Opt in from a host:
#   imports = [ self.nixosModules.wayland ];
{
  self,
  ...
}:
{
  flake.nixosModules.wayland =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # NVIDIA exists on exactly one of the two hosts (NIXPC, the x86 one), so
      # gate its decode diagnostics on the platform rather than per host — a
      # future host picks them up from its own hardware instead of someone
      # maintaining a host list here.
      isX86 = pkgs.stdenv.hostPlatform.isx86;
    in
    {
      imports = [ self.nixosModules.portals ];

      environment.systemPackages =
        with pkgs;
        [
          # --- X11 / XWayland side: diagnose and steer the X server ----------
          # `xdpyinfo` is the X equivalent of `wayland-info`; `xprop` reads the
          # window properties apps publish; `xinput`/`xrandr`/`xset` cover
          # input devices, output geometry and X resources. This is the set
          # you need to answer "why is this app in X11, and what does it think
          # its screen is?".
          xorg.xauth
          xorg.xdpyinfo
          xorg.xhost
          xorg.xinput
          xorg.xkill
          xorg.xlsclients
          xorg.xmodmap
          xorg.xprop
          xorg.xrandr
          xorg.xset
          xorg.xwininfo
          xorg.xkbcomp
          # Cross-selection for X11 apps. `wl-copy`/`wl-paste` only speak
          # Wayland, so without these an X11-to-Wayland copy silently does
          # nothing; with both, selection moves either way.
          xclip
          xsel

          # --- Wayland-native side -----------------------------------------
          # `weston` is here for `wayland-info`, the Wayland equivalent of
          # `xdpyinfo`: it reports which globals an XWayland or native client
          # actually negotiated, which is the first thing to check when a
          # client falls back to X11.
          weston
          wl-clipboard
          cliphist

          # --- wlroots compositor control (Mango) ------------------------
          # Mango speaks the same protocols as sway: these are its output,
          # screenshot and locking tools.
          wlr-randr # output geometry, modes and EDID
          wlrctl # switch output / set scale without a keybind
          grim # wayland-native screenshot
          slurp # region picker for `grim -g "$(slurp)"`
          wf-recorder # wlroots screen recorder
          wl-screenrec # alternative wlroots recorder
          swaylock
          swayidle
          wtype # virtual keyboard (wayland)
          dotool # virtual keyboard/mouse (X11) — the XWayland counterpart
          xwayland # standalone Xwayland, for reproducing a compositor's X11

          # --- Qt + theme glue so XWayland stops looking foreign ------------
          # Without these, Qt apps on XWayland draw their own widgets, ignore
          # the desktop theme and show an unthemed cursor.
          qt5.qtwayland
          qt6.qtwayland
          libxcb-cursor
          xsettingsd
          adwaita-icon-theme
          paper-icon-theme

          # --- Input method frontends --------------------------------------
          # Packaged only, deliberately not enabled or autostarted: enabling
          # an IME changes how you type, so that stays your call. fcitx5
          # works in native Wayland and in XWayland alike, and the GTK
          # frontend covers both toolkits' apps.
          fcitx5 # ships fcitx5-remote, fcitx5-diagnose, fcitx5-configtool
          fcitx5-gtk

          # --- Graphics / media acceleration diagnostics -------------------
          libva-utils # vainfo — is hardware video decode actually there?
          vulkan-tools # vulkaninfo
          mesa-demos # glxgears, vsyncinfo, vidmodeinfo for frame timing
        ]
        # vdpauinfo is NVIDIA's own decode path, separate from VA-API.
        ++ lib.optionals isX86 [ pkgs.vdpauinfo ];

      # --- Keychain: polkit agent -----------------------------------------
      # polkitd is already enabled system-wide, but with no agent registered
      # a polkit request has nobody to ask you for a password, so GUI actions
      # fail instead of prompting. polkit-gnome is the lightest agent that is
      # not tied to GNOME Shell, and it is compositor-agnostic.
      systemd.user.services.polkit-gnome = {
        description = "polkit-gnome authentication agent";
        # Wanted by default.target too: this desktop is started by the
        # Noctalia greeter into a Mango session, and that session is not
        # guaranteed to pull in graphical-session.target. systemd starts the
        # unit once either way.
        wantedBy = [
          "graphical-session.target"
          "default.target"
        ];
        after = [ "graphical-session-pre.target" ];
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.PolicyKit1.Authority";
          ExecStart = "${pkgs.polkit_gnome}/bin/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
        };
      };

      # --- Keychain: session keyring -------------------------------------
      # The login keyring that stores application secrets. Enabling it also
      # unlocks the keyring at login via PAM and publishes the Secret portal,
      # so apps can ask it to remember a credential instead of prompting every
      # time.
      services.gnome.gnome-keyring.enable = lib.mkDefault true;

      # --- Fewer password prompts -----------------------------------------
      # Two caches, both time-boxed, so "enter my sudo password" is not a
      # per-command event:
      #   sudo      — remembers a successful sudo for an hour (up from the
      #               5-minute upstream default).
      #   polkit    — remembers an authorization you granted for 30 minutes
      #               (up from polkit's 300-second default).
      # Neither stores the password, and `security.sudo.wheelNeedsPassword`
      # stays on: the password is still required, just not retyped constantly.
      security.sudo.extraConfig = lib.mkAfter ''
        Defaults timestamp_timeout=60
      '';

      security.polkit.settings.Polkitd.ExpirationSeconds = 1800;
    };
}
