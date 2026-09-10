---
name: computer-use
description: "Drive the local Wayland desktop from an OMP session with the dendritic computer-use toolchain: grim screenshot plus vision read, wtype keyboard, wlrctl pointer and toplevel, wlr-randr outputs, and the MCP agent-browser for web pages. Use for computer use, screen capture, clicking, GUI automation, or reading what is on the screen."
---

# Computer use on this workstation

Session facts: `XDG_SESSION_TYPE=wayland`, `WAYLAND_DISPLAY=wayland-0`, `DISPLAY=:0` (XWayland). The desktop is `mango` (nightly) plus `noctalia` 5.x on NIXPC and `niri` on ASAHI. Both are wlroots-based, so wlroots protocol clients work. X11 tools are useless here.

Verified on NIXPC on 2026-09-10 with `wayland-info`. The compositor exposes `zwlr_screencopy_manager_v1`, `zwlr_virtual_pointer_manager_v1`, `zwp_virtual_keyboard_manager_v1`, `zwlr_foreign_toplevel_manager_v1`, `zwlr_output_manager_v1`, and `zwlr_layer_shell_v1`.

## Toolchain

The dendritic `computer-use` feature installs these on both hosts. `attrs/desktop` imports it.

| Binary | Job |
|---|---|
| `grim` | screenshot of the whole layout, one output, a region, or one toplevel |
| `slurp` | region picker for `grim -g "$(slurp)"` |
| `wtype` | type text and named keys into the focused client |
| `wlrctl` | move or click the pointer, manage toplevels, query outputs |
| `wlr-randr` | output geometry and EDID identity |
| `wayland-info` | which protocols the compositor really exposes |

Absent on purpose: `xdotool` and `wmctrl` (X11 only), `ydotool` (`/dev/uinput` is root-only here), `chromium` and `playwright` (use the MCP browser instead).

If a machine does not have the feature yet, fetch on demand: `nix shell nixpkgs#wtype -c wtype ""`.

## Observe: screenshot, then vision

```bash
grim /tmp/screen.png                  # whole layout (3840x1080 = both monitors)
grim -o DP-2 /tmp/screen.png          # one output
grim -s 0.5 /tmp/screen.png           # half scale: cheaper to read, less detail
grim -g "100,200 800x600" /tmp/r.png  # region in layout coordinates, no mouse
grim -g "$(slurp)" /tmp/r.png         # region picked with the mouse
grim -c /tmp/screen.png               # include the cursor
```

`read /tmp/screen.png` returns image metadata only. Ask the vision model instead:

- `read "/tmp/screen.png?q=What dialog is open, and which buttons does it show?"`

Delete the PNG when done. It shows the user's live desktop.

Outputs, EDID-verified 2026-09-07 with `wlr-randr`: `DP-2` is a HUAWEI AD80HW and `DP-1` is an AOC 24G2W1G3-. Re-check with `wlr-randr` before trusting a comment.

## Act

Keyboard with `wtype`. Modifiers are `shift`, `capslock`, `ctrl`, `logo`, `win`, `alt`, and `altgr`. Named keys resolve through libxkbcommon, for example `Left` or `Home`.

```bash
wtype "hello"                  # type text
wtype -M ctrl -k c -m ctrl     # Ctrl+C: press modifier, key, release modifier
wtype -k Return                # one named key
wtype -d 50 "slow"             # 50 ms between keystrokes
```

Pointer and windows with `wlrctl`:

```bash
wlrctl pointer move 40 -20               # dx right, dy down, negatives allowed
wlrctl pointer click                     # left click (the default button)
wlrctl pointer click right               # left, right, or middle
wlrctl pointer scroll 3 0                # vertical, then horizontal
wlrctl toplevel focus app_id:firefox     # also title:…, state:active; bare value = app_id
wlrctl toplevel find title:Dolphin       # exit 0 iff a match exists
wlrctl toplevel waitfor app_id:brave      # block until a match appears
wlrctl toplevel minimize state:active    # also maximize, fullscreen
wlrctl output list                       # the compositor's output names
```

`wlrctl toplevel` manages windows but cannot list them. The actions are `focus`, `find`, `wait`, `waitfor`, `minimize`, `maximize`, and `fullscreen`. Use `find` to test a match, and a screenshot to learn what is actually on screen. There is no `wmctrl` equivalent for move or resize.

## Safety rule (hard)

Injected input goes to whatever window holds focus. Never inject into ambient focus.

- Prove the protocol with `wtype ""`. It exits 0 and types nothing.
- Need to type? Spawn a window you own, confirm focus with `wlrctl toplevel find state:active app_id:<id>` or a fresh screenshot, then type into it.
- Send a web page to the browser tools, not to desktop injection.
- `wtype -d 0` fails with `Invalid sleep time` and exit 1 before it opens the virtual keyboard. Do not read that exit as proof that typing is broken.

## Browser work

The harness `browser.open` fails on this machine. No local Chromium or Playwright binary exists, so it times out after 30 s. Use the MCP tools:

```jsonc
// write to xd://mcp__agent_browser_open
{"url": "about:blank", "timeoutMs": 45000}
```

The reply reports `data.lifecycle.effectiveLaunch.browserLaunched` and the engine. Then `agent_browser_snapshot` for element refs, `_click` / `_type` / `_fill`, `_screenshot` for visual proof, and `_close` when done. `headed: true` shows the window on the user's screen, which is intrusive. Ask first.

## Verify the toolchain

```bash
grim /tmp/t.png && stat -c '%s' /tmp/t.png   # nonzero size = capture works
wtype ""; echo $?                            # 0 = virtual keyboard protocol bound
wlrctl pointer move 2 2; echo $?             # 0 = virtual pointer protocol bound
wlrctl output list                           # compositor answers output queries
wayland-info | grep -c virtual_keyboard      # 1 = protocol advertised
```

## Worked loop

1. `grim /tmp/s.png`, then `read "/tmp/s.png?q=…"` to see the current state.
2. Decide the next action from that text, never from memory.
3. Act with `wtype` or `wlrctl`. Use the MCP browser for web pages.
4. Capture again and confirm the change. Report the confirmation.
5. Delete the PNGs.

## Pitfalls

- `grim` writes to `$GRIM_DEFAULT_DIR`, then `$XDG_PICTURES_DIR`, then the current directory when no file argument is given. Always pass an explicit path.
- The whole-layout capture is 3840x1080, so a full read is expensive. Capture the region you need, or add `-s 0.5`.
- `slurp` blocks until the user picks a region. Use `grim -g "x,y WxH"` when the agent knows the geometry.
- A null-cursor capture is normal. Add `-c` only when the cursor position matters.
