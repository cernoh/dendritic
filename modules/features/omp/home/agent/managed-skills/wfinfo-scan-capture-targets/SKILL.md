---
name: wfinfo-scan-capture-targets
description: "Choose and verify which display or window a WFinfo-ext reward-screen scan captures: grim -o/-g semantics on mango, window-geometry sources (mmsg vs wlrctl), the pixel-hash equivalence proof without ImageMagick, and the flake-check untracked-file trap."
---

# WFinfo-ext scan capture targets (WFinfo-ext repo)

Companion to the user skill `wfinfo-dashboard` (data files, gates) and
`wfinfo-flake-run-apps` (running flake apps; live-server proof when the hub
broker is down). This skill covers *what a scan captures*.

## Verified host facts (NIXPC workstation, mango compositor)

- `grim -o <name>` captures one output. Names come from
  `wlr-randr --json` (`name`, `enabled`, `position.x/y`, `modes[].current`).
- `grim -g "X,Y WxH"` uses **layout coordinates** — the same space as monitor
  positions. Verified empirically: `grim -g "1920,0 200x200"` is byte-identical
  to the top-left 200x200 of `grim -o DP-2` when DP-2 sits at x=1920.
- `mmsg get all-clients` (mango IPC) reports per-client `x,y,width,height`
  directly usable as that region — no conversion. Also gives `appid`, `title`,
  `monitor`, `is_focused`, `is_visible`. Drop clients with zero size or
  `is_visible: false`.
- `mmsg get all-layers` is NOT a command (`{"error":"unknown command"}`).
  `mmsg get last_open_surface <mon>` returns only a surface *name*, no geometry.
- `wlrctl toplevel list` prints `appid: title` lines — names only. Wayland has
  no portable window-geometry protocol, so under a non-mango compositor a
  window list can only be names; display capture still works.
- `mmsg` is not in nixpkgs (only `mangowc`); it arrives from the user's system
  PATH. Do not add it to flake deps — discovery degrades gracefully instead.

## Pixel-equivalence proof without ImageMagick/python3

This host has neither. Use ffmpeg raw RGB24 + sha256, comparing region captures
against their equivalents:

```bash
grim -o DP-2 /tmp/dp2.png
grim -g "1920,0 200x200" /tmp/reg2.png
for f in dp2 reg2; do printf '%-6s ' $f; ffmpeg -v error -i /tmp/$f.png \
  -f rawvideo -pix_fmt rgb24 - 2>/dev/null | sha256sum; done
printf 'crop   '; ffmpeg -v error -i /tmp/dp2.png -vf crop=200:200:0:0 \
  -f rawvideo -pix_fmt rgb24 - 2>/dev/null | sha256sum
```

`reg2` and `crop` must match; `dp2` differs. That is the proof region coords are
layout coords, not per-output coords.

## Runner side (headless/)

- `WFInfo.Headless --scan` captures ONE image when pinned: `--file <png>`,
  `--region "X,Y WxH"`, or `--output <name>` (precedence in that order).
  Unpinned, it tries every output then the joined image.
- `ScanOptions.ParseRegion` normalizes to `X,Y WxH` and rejects non-positive
  sizes; `ScreenCapture.Capture(output, region, destination)` maps region→`-g`,
  output→`-o`, both null→whole layout.
- The pin is reported verbatim as the record's `CaptureTarget`, so a region
  shows as the region text, not a monitor name.
- Smoke each mode and read the `capture:` line:
  `dotnet headless/bin/Debug/net9.0/WFInfo.Headless.dll --scan --no-notify [pin]`.

## Dashboard side (dashboard/src)

- `lib/targets.ts` owns discovery, parsers, and the choice→args mapping. The
  form carries **tokens** (`display:DP-2`, `window:7`), never bare names; the
  server resolves the token against live geometry at scan start, so a closed
  window is refused (400) instead of silently substituted.
- Discovery is read-only, best-effort, memoised ~3 s; `?refresh=1` skips the
  memo. A missing tool shortens the list and adds a note, never fails the page.
- Claim the scan slot **before the first `await`** in `POST /scan/run`
  (`scanStarting` flag alongside `scanner.busy`): reading the form and targets
  is async, and two overlapping requests must not both start a scan.

## Repo traps

- **`nix flake check` copies only tracked files.** A new `dashboard/src/lib/*.ts`
  is invisible to the sandbox copy → `TS2307 Cannot find module`. `git add` new
  files before running the check, or the failure is bogus.
- `Deno.remove(path, { force: true })` does not exist in this Deno version —
  wrap in try/catch.
- `deno lint` skips `src/static/dashboard.js` (browser globals) but `deno fmt`
  does format it — run `deno fmt` (not just `--check`) after editing it.
- Live-server proof: `hub op start` fails here (`broker.sock` ENOENT) and bash
  refuses `nohup`/`&`. Drive it from the eval kernel with `Bun.spawn` and poll
  stdout for `listening: http://localhost:<port>`; stop with
  `Bun.spawnSync(["pkill","-f","src/main.ts"])`. Browser check: `agent_browser`
  open + screenshot + `eval` on element ids (`wf-scan-display`, `wf-scan-window`,
  `wf-scan-refresh`, `wf-scan-button`, `wf-scan-status`).
