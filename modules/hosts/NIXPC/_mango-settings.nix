# The MangoWM facts that belong to this machine (issue #245). The feature
# module (modules/features/mango) holds the settings both hosts share; this
# file feeds the rest through `dendritic.mango` (assigned in
# nixpcConfiguration.nix).
{
        # EDID-verified 2026-09-07 via wlr-randr: DP-1 = AOC 24G2W1G3-,
        # DP-2 = HUAWEI AD80HW (earlier notes had these reversed). DP-1 is the AOC
        # at the center/left; DP-2 is the HUAWEI immediately to its right.
        monitorRule = [
                "name:^DP-1$, vrr:1, refresh:165,x:0,y:0,scale:1"
                "name:^DP-2$,x:1920,y:0,scale:1"
        ];

        # NVIDIA/Wayland GPU vars. They reach the compositor and its spawn_shell
        # children through mango's own env list, because that session never sources
        # a profile (issue #86); nixpc-desktop repeats them in
        # environment.sessionVariables for login shells and systemd user units
        # (issue #95).
        extraEnv = [
                "GBM_BACKEND,nvidia-drm"
                "__GLX_VENDOR_LIBRARY_NAME,nvidia"
                "LIBVA_DRIVER_NAME,nvidia"
                "WLR_NO_HARDWARE_CURSORS,1"
                "WLR_RENDERER_ALLOW_SOFTWARE,1"
                # Steam and its Electron windows.
                "SDL_VIDEODRIVER,wayland,x11"
                "STEAM_USE_DYNAMIC_VGUI,1"
        ];

        # Move the focused client to the AOC (DP-1, left) or the HUAWEI (DP-2,
        # right) monitor (issue #114).
        extraBinds = [
                "SUPER+ALT,H,tagmon,DP-1,1"
                "SUPER+ALT,L,tagmon,DP-2,1"
        ];

        # Tuned on this host: 10 px gaps, 5 px border.
        gaps = 10;
        borderWidth = 5;
}
