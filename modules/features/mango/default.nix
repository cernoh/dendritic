# MangoWM feature: NIXPC's compositor session, ported from
# ~/.config/home-manager-v3/config/mango.nix.
#
# The input's modules default `package` to their own build
# (packages.<system>.mango), so no overlay wiring is needed — unlike hm-v3,
# whose overlay only served unrelated pkgs.mangowm references.
#
# Homeless config (issue #97, policy #93): the whole settings render moved
# system-side. The config is evaluated into the store (validated at build
# time with `mango -c -p`), and the session root is packaged as a wrapper
# that launches mango with `-c <store config>` — no ~/.config/mango owned by
# a home-manager profile, no HM activation clock to reconcile.
#
# What stays out: noctalia (separate feature) and the terminal. Helper
# binaries the bindings/autostart invoke are system packages now.
#
# NOTE on the settings lists below: the renderer emits every list element
# as a config line, so keep comments as Nix comments between elements and
# never inside the string values themselves.
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.mango =
    {
      lib,
      pkgs,
      ...
    }:
    let
      realMango = inputs.mangowm.packages.${pkgs.stdenv.hostPlatform.system}.mango;

      # Same renderer the mangowm HM module used, so the config text is
      # byte-identical for the settings (verified: diff rendered config
      # before/after, issue #97).
      toMango = (import "${inputs.mangowm}/nix/lib.nix" lib).toMango { };

      # Session-root autostart: replicating what the HM module's
      # autostart_sh wrapper did — import the session env into the systemd/
      # dbus user environment, start the session target, then the helpers.
      autostartSh = pkgs.writeShellScript "mango-autostart.sh" ''
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE NIXOS_OZONE_WL XCURSOR_THEME XCURSOR_SIZE
        systemctl --user reset-failed
        systemctl --user start mango-session.target
        udiskie &
      '';

      settings = {
        # Mango setenv()s these entries in-process; children of
        # spawn_shell inherit them. TERMINAL and the NVIDIA/Wayland GPU
        # vars live HERE (not the ghostty/nixpc-desktop features) because
        # nixpkgs' module system rejects any def of an option undeclared
        # on the host — including mkIf-false guards — and ASAHI has no
        # mango options (issue #86). The same vars are also delivered via
        # environment.sessionVariables for login-shell consumers (issue
        # #95); the compositor channel is the one that actually reaches
        # greeter-spawned mango and its spawns.
        env = [
          "XCURSOR_SIZE,24"
          "TERMINAL,ghostty"
          "GBM_BACKEND,nvidia-drm"
          "__GLX_VENDOR_LIBRARY_NAME,nvidia"
          "LIBVA_DRIVER_NAME,nvidia"
          "WLR_NO_HARDWARE_CURSORS,1"
          "WLR_RENDERER_ALLOW_SOFTWARE,1"
          "SDL_VIDEODRIVER,wayland,x11"
          "STEAM_USE_DYNAMIC_VGUI,1"
        ];
        # DP-2 is the AOC; place it at the center/left of the two connected outputs.
        monitorrule = [
          "name:^DP-2$,x:0,y:0,scale:1"
          # DP-1 is the HUAWEI; place it immediately to the right.
          "name:^DP-1$,x:1920,y:0,scale:1"
        ];

        repeat_rate = 35;
        repeat_delay = 200;
        numlockon = 1;

        tap_to_click = 1;
        trackpad_natural_scrolling = 1;
        trackpad_accel_profile = 1;
        trackpad_accel_speed = 0.2;

        mouse_natural_scrolling = 0;

        sloppyfocus = 1;
        warpcursor = 1;
        focus_cross_monitor = 1;
        exchange_cross_monitor = 1;

        gappih = 10;
        gappiv = 10;
        gappoh = 10;
        gappov = 10;
        borderpx = 5;
        focuscolor = "0xCD7F32ff";
        bordercolor = "0x505050ff";
        urgentcolor = "0x9b0000ff";
        rootcolor = "0x1e1e2eff";

        border_radius = 5;
        shadows = 0;
        shadows_size = 5;
        shadows_blur = 30;
        shadows_position_x = 0;
        shadows_position_y = 5;
        shadowscolor = "0x00000070";

        animations = 1;
        layer_animations = 1;
        animation_type_open = "zoom";
        animation_type_close = "fade";
        animation_fade_in = 1;
        animation_fade_out = 1;

        scroller_default_proportion = 0.5;
        scroller_proportion_preset = "0.33,0.5,0.67";
        scroller_focus_center = 0;
        scroller_prefer_center = 0;
        circle_layout = "scroller,tile,monocle,grid";

        tagrule = [
          "id:1,layout_name:scroller,no_hide:1"
          "id:2,layout_name:scroller,no_hide:1"
          "id:3,layout_name:scroller,no_hide:1"
          "id:4,layout_name:scroller,no_hide:1"
          "id:5,layout_name:scroller"
          "id:6,layout_name:scroller"
          "id:7,layout_name:scroller"
          "id:8,layout_name:scroller"
          "id:9,layout_name:scroller"
        ];

        windowrule = [
          "isfloating:1,appid:firefox,title:^Picture-in-Picture$"
          "allow_csd:0,appid:.*"
        ];

        mousebind = [
          "SUPER,btn_left,moveresize,curmove"
          "SUPER,btn_right,moveresize,curresize"
        ];

        axisbind = [
          "SUPER,UP,viewtoleft_have_client"
          "SUPER,DOWN,viewtoright_have_client"
        ];

        # Move the focused client to the HUAWEI (DP-1, right) or AOC (DP-2, left) monitor.
        bind = [
          "SUPER+ALT,L,tagmon,DP-1,1"
          "SUPER+ALT,H,tagmon,DP-2,1"
          "SUPER,T,spawn_shell,$TERMINAL"
          "SUPER+SHIFT,T,spawn_shell,noctalia msg panel-toggle cernoh/terminal:panel"
          "SUPER,D,spawn_shell,noctalia msg panel-open launcher"
          "SUPER+ALT+SHIFT,L,spawn_shell,swaylock --screenshots --clock --indicator --indicator-radius 100 --indicator-thickness 7 --effect-blur 7x5 --effect-vignette 0.5:0.5 --ring-color bb00cc --key-hl-color 880033 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --grace 2 --fade-in 0.2"
          "SUPER,Q,killclient"
          "SUPER,F,togglemaximizescreen"
          "SUPER+SHIFT,F,togglefullscreen"
          "SUPER,V,togglefloating"
          "SUPER,O,toggleoverview"
          "SUPER,W,setlayout,monocle"
          "SUPER,C,centerwin"
          "SUPER,Left,focusdir,left"
          "SUPER,Down,focusdir,down"
          "SUPER,Up,focusdir,up"
          "SUPER,Right,focusdir,right"
          "SUPER,H,focusdir,left"
          "SUPER,J,focusdir,down"
          "SUPER,K,focusdir,up"
          "SUPER,L,focusdir,right"
          "SUPER+CTRL,Left,exchange_client,left"
          "SUPER+CTRL,Down,exchange_client,down"
          "SUPER+CTRL,Up,exchange_client,up"
          "SUPER+CTRL,Right,exchange_client,right"
          "SUPER+CTRL,H,exchange_client,left"
          "SUPER+CTRL,J,exchange_client,down"
          "SUPER+CTRL,K,exchange_client,up"
          "SUPER+CTRL,L,exchange_client,right"
          "SUPER+SHIFT,M,tagmon,right,1"
          "SUPER+SHIFT,Left,focusmon,left"
          "SUPER+SHIFT,Down,focusmon,down"
          "SUPER+SHIFT,Up,focusmon,up"
          "SUPER+SHIFT,Right,focusmon,right"
          "SUPER+SHIFT,H,focusmon,left"
          "SUPER+SHIFT,J,focusmon,down"
          "SUPER+SHIFT,K,focusmon,up"
          "SUPER+SHIFT,L,focusmon,right"
          "SUPER+SHIFT+CTRL,Left,tagmon,left,1"
          "SUPER+SHIFT+CTRL,Down,tagmon,down,1"
          "SUPER+SHIFT+CTRL,Up,tagmon,up,1"
          "SUPER+SHIFT+CTRL,Right,tagmon,right,1"
          "SUPER+SHIFT+CTRL,H,tagmon,left,1"
          "SUPER+SHIFT+CTRL,J,tagmon,down,1"
          "SUPER+SHIFT+CTRL,K,tagmon,up,1"
          "SUPER+SHIFT+CTRL,L,tagmon,right,1"
          "SUPER,Page_Down,viewtoright_have_client"
          "SUPER,Page_Up,viewtoleft_have_client"
          "SUPER,U,viewtoright_have_client"
          "SUPER,I,viewtoleft_have_client"
          "SUPER+CTRL,Page_Down,tagtoright"
          "SUPER+CTRL,Page_Up,tagtoleft"
          "SUPER+CTRL,U,tagtoright"
          "SUPER+CTRL,I,tagtoleft"
          "SUPER,1,view,1"
          "SUPER,2,view,2"
          "SUPER,3,view,3"
          "SUPER,4,view,4"
          "SUPER,5,view,5"
          "SUPER,6,view,6"
          "SUPER,7,view,7"
          "SUPER,8,view,8"
          "SUPER,9,view,9"
          "SUPER+CTRL,1,tag,1"
          "SUPER+CTRL,2,tag,2"
          "SUPER+CTRL,3,tag,3"
          "SUPER+CTRL,4,tag,4"
          "SUPER+CTRL,5,tag,5"
          "SUPER+CTRL,6,tag,6"
          "SUPER+CTRL,7,tag,7"
          "SUPER+CTRL,8,tag,8"
          "SUPER+CTRL,9,tag,9"
          "SUPER,bracketleft,scroller_stack,left"
          "SUPER,bracketright,scroller_stack,right"
          "SUPER,comma,scroller_stack,left"
          "SUPER,period,scroller_stack,right"
          "SUPER,R,switch_proportion_preset"
          "SUPER,minus,resizewin,-50,0"
          "SUPER,equal,resizewin,50,0"
          "SUPER+SHIFT,minus,resizewin,0,-50"
          "SUPER+SHIFT,equal,resizewin,0,50"
          "SUPER,N,switch_layout"
          "SUPER+SHIFT,S,spawn_shell,grimshot copy area || grim -g \"$(slurp)\" - | wl-copy"
          "CTRL,Print,spawn_shell,grimshot copy screen || grim - | wl-copy"
          ''ALT,Print,spawn_shell,grimshot copy window || grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"')" - | wl-copy''
          "SUPER,Escape,setoption,allow_shortcuts_inhibit,0"
          "SUPER+SHIFT,E,quit"
          "CTRL+ALT,Delete,quit"
          "SUPER+SHIFT,P,spawn_shell,wlr-dpms off"
          "SUPER,Home,focusstack,prev"
          "SUPER,End,focusstack,next"
        ];

        bindl = [
          "NONE,XF86AudioRaiseVolume,spawn_shell,wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
          "NONE,XF86AudioLowerVolume,spawn_shell,wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%-"
          "NONE,XF86AudioMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          "NONE,XF86AudioMicMute,spawn_shell,wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          "NONE,XF86MonBrightnessUp,spawn_shell,brightnessctl -e4 -n2 set 1%+"
          "NONE,XF86MonBrightnessDown,spawn_shell,brightnessctl -e4 -n2 set 1%-"
          "NONE,XF86AudioPlay,spawn_shell,playerctl play-pause"
          "NONE,XF86AudioStop,spawn_shell,playerctl stop"
          "NONE,XF86AudioPrev,spawn_shell,playerctl previous"
          "NONE,XF86AudioNext,spawn_shell,playerctl next"
          "SUPER+ALT,S,spawn_shell,pkill orca || exec orca"
        ];
      };

      # The settings render, plus exec-once for the session-root autostart
      # (identical structure to the HM module's finalConfigText: toMango +
      # "\nexec-once=...\n").
      configText = (toMango settings) + "\nexec-once=${autostartSh}\n";

      # Build-time validation, exactly like the HM module's validatedConfig:
      # mango -c <file> -p checks the config before it ever ships.
      configFile = pkgs.runCommand "mango-config.conf" { } ''
        cp ${pkgs.writeText "mango-config.conf" configText} "$out"
        ${realMango}/bin/mango -c "$out" -p || exit 1
      '';

      # Session entry stays intact (programs.mango.package feeds
      # systemPackages + displayManager.sessionPackages); only bin/mango is
      # replaced with the -c wrapper. The desktop file's Exec=mango resolves
      # via PATH, so both the greeter session and manual `mango` invocations
      # always use the flake-owned config.
      mangoWrapped = pkgs.symlinkJoin {
        name = "mango-wrapped";
        paths = [ realMango ];
        # displayManager.sessionPackages requires `providedSessions` on the
        # package (it builds the session directory from it) — carry the real
        # package's passthru over the join.
        passthru = realMango.passthru;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          rm -f "$out/bin/mango"
          makeWrapper ${realMango}/bin/mango "$out/bin/mango" --add-flags "-c ${configFile}"
        '';
      };
    in
    {
      imports = [ inputs.mangowm.nixosModules.mango ];

      programs.mango = {
        enable = true;
        package = mangoWrapped;
      };

      # Same session target the mangowm HM module declared (systemd.enable),
      # so user services bound to mango-session.target keep working. (NixOS
      # option shape: lowercase flat attrs, unlike HM's systemd module.)
      systemd.user.targets.mango-session = {
        description = "mango compositor session";
        documentation = [ "man:systemd.special(7)" ];
        bindsTo = [ "graphical-session.target" ];
        wants = [ "graphical-session-pre.target" ];
        after = [ "graphical-session-pre.target" ];
      };

      # Helper binaries referenced by bindings/autostart. Noctalia (including
      # its notification daemon, which claims org.freedesktop.Notifications)
      # and the terminal are deliberately absent — they are separate features.
      # (Formerly home.packages in the HM module; moved system-side with the
      # homelessness change, issue #97.)
      environment.systemPackages = with pkgs; [
        udiskie
        brightnessctl
        grim
        slurp
        wl-clipboard-rs
        # SUPER+ALT+L passes --effect-* flags; plain swaylock ignores them.
        swaylock-effects
      ];
    };
}
