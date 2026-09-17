---
name: koreader-kindle-crash-forensics
description: "Diagnose and fix KOReader/plugin crashes on a jailbroken Kindle from a remote session: crash.log reading, the dropbear SSH quirks, and the httpinspector /koreader/globals/ REPL for live Lua probes, real-UI driving, offscreen paints, and durable fixes in koreader/patches/. Use when a Kindle KOReader plugin \"keeps crashing\", when crashlog must be read, or when a KOReader crash must be proven and fixed without touching the device by hand."
---

# KOReader crash forensics on a jailbroken Kindle

## Access
- `ssh -p 2222 root@<ip>` (KOReader dropbear, **no password**). OpenSSH refuses an empty
  password interactively from a tool; use an askpass helper:
  ```sh
  printf '#!/bin/sh\nprintf "%%s\\n" ""\n' > /tmp/askpass.sh; chmod +x /tmp/askpass.sh
  SSH_ASKPASS=/tmp/askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0 \
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 root@<ip> 'id'
  ```
  `BatchMode=yes` disables password auth — omit it.
- Wrapper scripts for repeat use (`/tmp/kd <cmd>`, `/tmp/kcp <remote> <local>`) pay off.
- `scp` over dropbear intermittently **hangs**. Transfer with
  `ssh ... 'base64 /path' > f.b64 && base64 -d f.b64 > f` instead.
- The shell is uid 0 with the same mount namespace as PID 1; `mntroot rw`, `eips`, `fbink`,
  `curl`, `iptables` are available.

## crash.log
- The file is `/mnt/us/koreader/crash.log` (not `crashlog`); it is the redirected stdout of
  KOReader and grows across launches.
- Hard crashes appear as `./luajit: <msg>` + `stack traceback:` with **no timestamp**; the
  timestamped lines around them are interleaved from several processes, so the crash time
  only brackets between the surrounding timestamps — do not assume it happened in the same
  second as the last `INFO` line. A crash that looks like "the same second as the last
  request" is often tens of seconds later, after the user tapped again.
- A bare `...` line **inside** a traceback is the printer's middle elision (the innermost
  and the outermost frames are kept). The frames between are lost, so crash.log alone
  cannot always name the dialog or plugin that owned the crashing widget — reproduce it
  live instead of guessing from the trace.
- Index all crashes: `grep -n '^\./luajit:' crash.log`.
- Lua *errors* caught by `Trapper`/`xpcall` show as `WARN error in wrapped function: ...`
  and are **not** crashes; separate them from the fatal ones.

## Live REPL: the httpinspector plugin (port 8081 default)
Enable it (KOReader → Tools → KOReader HTTP inspector), then:
- `GET /koreader/` — entry points: `ui/` (FileManager/ReaderUI instance), `device/`,
  `g_settings/`, `globals/` (= `_G`), `UIManager/`, `event/`, `broadcast/`.
- `/koreader/globals/package/loaded/<Module>/` — browse a loaded module.
- `/koreader/<path-to-function>/arg1/arg2/` — **call** it; args are path segments
  (`'quoted'` or `"quoted"` for special characters). Return value is JSON.
- `/koreader/<path>/` on a table — browse; `<path>?=` — assign a property.
- Calls run under `xpcall`, so **an error in your call is returned to you as JSON and does
  not kill KOReader**. This makes it a safe harness.
- Requests are served in the pluginloader handler sandbox on the main thread: UI calls work,
  and a change to a Lua file needs a restart only because modules are cached in memory.

### Probe pattern (arbitrary Lua without a restart)
1. Write a probe file to the KOReader data dir, e.g. `/mnt/us/koreader/probe.lua` (cwd is
   `/mnt/us/koreader`, so `dofile` needs no slash in the URI).
2. `GET /koreader/globals/dofile/probe.lua/` — runs it in the live process.
3. The probe defines `_G.__probe(arg)`; call `GET /koreader/globals/__probe/mode/`.
4. **Every upload needs a new `dofile`**; and a probe that patches a module is installed
   only if its guard flag is unset — if you change the patch code, reinstall it
   (`if P.orig then TW.setMaxWidth = P.orig end` first) and look state up at call time
   (`_G.__PROBE`), not in a captured closure. A stale closure silently keeps the old code.
5. Clean up: remove the probe file, restore the patched method, and `_G.__PROBE = nil`.
6. `require("lfs")` is wrong inside a probe (KOReader ships `libs/libkoreader-lfs`), and a
   `require` inside the served path can fail through an unrelated transitive load. Prefer
   reaching already-loaded modules via `package.loaded[...]`, and keep the dofile body
   free of top-level requires where practical.

### Driving the real UI from the probe
- `UIManager._window_stack` — what is on screen (`.widget.name` / `.title` / `.page`).
- `UIManager:close(w)` — close your own widget; close only what you opened.
- Call plugin entry points directly, e.g.
  `/koreader/globals/package/loaded/AvailableSourcesListing/fetchAndShow/nil/` reproduces
  exactly what the rakuyomi menu does, and `top:onNextPage()` then pages the real listing.
- Offscreen paint for evidence: `Blitbuffer.new(w, h, Blitbuffer.TYPE_BBRGB32)`,
  `bb:fill(Blitbuffer.COLOR_WHITE)`, `widget:paintTo(bb, x, y)` inside `pcall`, then
  `bb:writePNG("/tmp/x.png")`. A default (8-bit) buffer paints text black-on-black — fill
  white and use RGB32. Fetch the PNG and look at it.

## Durable fixes
- `/mnt/us/koreader/patches/` is scanned by `frontend/userpatch.lua`; file names must match
  `<priority digits>-*.lua`, e.g. `2-foo.lua`. Priorities: `0` early_once, `1` early,
  `2` late (after UIManager is ready), `8` before_exit, `9` on_exit.
- An `early` patch runs **before** `G_defaults`/`G_reader_settings` exist — requiring UI
  modules there crashes. Use `2` for UI patches; use `1` only for pure app config.
- Priority 2 runs before the plugins are instantiated; to patch a plugin module, use
  `userpatch.registerPatchPluginFunc("pluginname", fn)` or `require` it lazily.
- The `patches/` dir survives KOReader updates and plugin self-updates (rakuyomi replaces
  only its own plugin dir), which makes it the right place for a guard.
- Verify without a restart: `dofile` the patch file from the REPL, then check behaviour.
  Verify the *startup path* by calling `require("userpatch").applyPatches("2")` and reading
  `userpatch.execution_status["<file>"]` plus the `Applying patch:` line in crash.log.

## Worked example: the rakuyomi "Available sources" crash
- Symptom: `./luajit: frontend/ui/widget/textwidget.lua:224: bad argument #2 to 'makeLine'
  (width must be strictly positive)`; KOReader dies while the source list is browsed.
- Chain: `AvailableSourcesListing:makeItem` puts a source's full language list in
  `post_text` (XCOMIC 426 chars) → `frontend/ui/widget/menu.lua` ListMenuItem subtracts
  `post_text_widget:getWidth() + paddings` from `available_width` without a floor →
  `item_name:setMaxWidth(negative)` → `TextWidget:updateSize` → `xtext:makeLine(width <= 0)`
  raises; nothing catches it in the paint path.
- Structural fingerprint of the crash trace: `UnderlineContainer > HorizontalGroup >
  OverlapGroup > LeftContainer > HorizontalGroup > TextWidget`. A stock ListMenuItem keeps
  the name TextWidget as a direct HorizontalGroup child; rakuyomi's MenuItemCover wrap in
  single-line mode inserts a `verticalgroup.lua` frame, and TouchMenuItem has no
  OverlapGroup/LeftContainer — so the fingerprint identifies the owning class.
- Guard that fixes it at the right layer (one file in `patches/`): wrap
  `TextWidget.setMaxWidth` and turn a non-positive width into `nil` (the row then uses the
  text's natural width and the container clips). Clamping to `1` also stops the crash but
  collapses the item name to an ellipsis, so prefer dropping the impossible width.
  Reinstalling it via httpinspector and paging the real listing through all pages proves the
  fix end to end.
