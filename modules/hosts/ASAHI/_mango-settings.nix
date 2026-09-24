# The MangoWM facts that belong to this machine (issue #245). ASAHI keeps
# niri and adds mango as a second session; these values are what niri gives
# the built-in panel, so either session looks the same.
{
        # The scale is the one value wlroots cannot work out on its own: niri picks a
        # scale from the panel's physical size (290x189 mm), mango does not — it
        # would run the panel at scale 1 and a 1x desktop on 224 dpi. Read from the
        # running niri session on 2026-09-22 (`niri msg outputs`): eDP-1, mode
        # 2560x1664 @ 60 Hz, logical size 1462x950, scale 1.75.
        monitorRule = [
                "name:^eDP-1$,x:0,y:0,scale:1.75"
        ];

        # niri's values from modules/features/niri/config.kdl: `gaps 16` and a 4 px
        # focus ring, which mango draws as the window border.
        gaps = 16;
        borderWidth = 4;

        tap_to_click = 0;
        tap_and_drag = 1;
        trackpad_click_method = 2;
        trackpad_natural_scrolling = 1;
        trackpad_disable_while_typing = 1;

}
