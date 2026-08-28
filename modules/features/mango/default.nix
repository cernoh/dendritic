# MangoWM feature: NixOS session + home-manager user config, ported from
# ~/.config/home-manager-v3/config/mango.nix.
#
# The input's modules default `package` to their own build
# (packages.<system>.mango), so no overlay wiring is needed — unlike hm-v3,
# whose overlay only served unrelated pkgs.mangowm references.
#
# NOTE on the settings lists below: the HM renderer emits every list element
# as a config line, so keep comments as Nix comments between elements and
# never inside the string values themselves.
{
  self,
  inputs,
  ...
}:
{
  # NixOS side: session entry for display managers, xdg portals,
  # polkit, xwayland.
  flake.nixosModules.mango =
    {
      lib,
      ...
    }:
    {
      imports = [ inputs.mangowm.nixosModules.mango ];

      programs.mango.enable = true;
    };

  # Home-manager side: user keybinds/rules/appearance. Opt in via
  # self.homeManagerModules.mango (NIXPC does).
  flake.homeManagerModules.mango =
    {
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.mangowm.hmModules.mango ];

      # Helper binaries referenced by bindings/autostart. Noctalia and the
      # terminal are deliberately absent — they are separate features.
      home.packages = with pkgs; [
        dunst
        udiskie
        brightnessctl
        grim
        slurp
        wl-clipboard-rs
        # SUPER+ALT+L passes --effect-* flags; plain swaylock ignores them.
        swaylock-effects
      ];

      wayland.windowManager.mango = {
        enable = true;
        systemd.enable = true;

        settings = {
          # NIXPC's terminal is ghostty; register TERMINAL here (not from the
          # ghostty feature) because nixpkgs' module system rejects any def of
          # an option undeclared on the host — including mkIf-false guards —
          # and ASAHI's ghostty has no mango option (issue #86). Mango
          # setenv()s entries in-process; children of spawn_shell inherit them.
          env = [
            "XCURSOR_SIZE,24"
            "TERMINAL,ghostty"
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

          # Move the focused panel from the main display to the secondary display.
          bind = [
            "SUPER,T,spawn_shell,$TERMINAL"
            "SUPER+SHIFT,T,spawn_shell,noctalia msg panel-toggle cernoh/terminal:panel"
            "SUPER,D,spawn_shell,noctalia msg panel-open launcher"
            "SUPER+ALT,L,spawn_shell,swaylock --screenshots --clock --indicator --indicator-radius 100 --indicator-thickness 7 --effect-blur 7x5 --effect-vignette 0.5:0.5 --ring-color bb00cc --key-hl-color 880033 --line-color 00000000 --inside-color 00000088 --separator-color 00000000 --grace 2 --fade-in 0.2"
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

        # No wallpaper autostart: noctalia's wallpaper module owns the
        # desktop background on every host; the v3 swaybg wrapper was
        # deliberately dropped (issue #28).
        autostart_sh = ''
          dunst &
          udiskie &
        '';
      };
    };
}
