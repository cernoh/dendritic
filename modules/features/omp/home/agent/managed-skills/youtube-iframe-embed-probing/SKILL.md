---
name: youtube-iframe-embed-probing
description: "Probe what an embedded YouTube player can do in a real browser (range, loop, autoplay, refusals) with the IFrame API over CDP: build the harness, establish a positive control before trusting any error code, and use the Referer identity lever and the /oembed oracle. Use when specifying a video preview, judging embed refusals, or testing playerVars."
---

# Probing the YouTube embed for real

Answers questions that documentation alone leaves vague ("does `end` survive a seek", "how does a
refusal arrive", "why is this page refused") with observed facts from a real browser. Worked
2026-09-18 on a x86_64 NixOS host with no display, against ticket cernoh/Sealplus#4.

## Rule zero: positive control first

Never record an error code before the same harness plays a known-embeddable video end to end:
`state 1`, `getDuration() > 0`, `getCurrentTime()` advancing. From a refused environment **every**
video returns `onError 150` — including nonexistent IDs and embeddable ones — so the code carries
no information about the video until the control plays. A refusal result without a control is a
statement about the host, not about the embed.

Second rule: change **one** variable per run and record which. It is easy to change scheme, host
and the `origin` playerVar at once and credit the wrong one.

## The identity lever (biggest single fact)

The gate is the `Referer` request header, not the page origin. Measured on one unchanged loopback
page (`http://127.0.0.1:8794`):

| Referer sent | Result |
|---|---|
| natural (`http://127.0.0.1:8794/...`) | `onError 150`, `duration 0`, state stuck at `-1` |
| forced `https://<application-id>/` | plays, `state 1` from the `start` second, `duration` = full length |
| none (top-level `youtube.com/embed/<id>`) | YouTube's own panel: "Video player configuration error. Error 153" |

Force it with CDP: `Network.enable` then `Network.setExtraHTTPHeaders: {headers:{Referer:"https://x/"}}`,
set **after** the first page load, then reload. Send the headers in the same `tab.run` as the reload —
a CDP session created in an earlier call may be disposed. `widget_referrer` is analytics-only and does
not lift the refusal. Docs: YouTube Required Minimum Functionality (`Referer: https://<app-id>/`;
Android route `loadUrl(url, additionalHttpHeaders)`), IFrame API reference (error `153` = no Referer).

## Harness

- Serve your own page; do not try to drive `youtube.com/embed` directly (cross-origin).
- Minimal host: `<script src="https://www.youtube.com/iframe_api">`, `onYouTubeIframeAPIReady` sets a
  flag, `window.makePlayer(hostId, opts)` builds `new YT.Player(div, {videoId, playerVars, events})`,
  and a 500 ms `setInterval` pushing `[getCurrentTime(), getPlayerState()]` into a global. Read the
  global out with `tab.evaluate` and parse it.
- `playerVars` are the iframe URL params: `enablejsapi:1, autoplay:1, mute:1, start, end, loop:1,
  playlist:<same id>, origin:<parent origin>`.
- Events: `onReady`, `onStateChange` (`-1` unstarted, `0` ended, `1` playing, `2` paused,
  `3` buffering, `5` cued), `onError(data)`, `onAutoplayBlocked`.
- Public HTTPS origin without a tunnel or account: publish the page as a gist (`gh gist create --public`)
  and load it through `https://gist.githack.com/<user>/<gist-id>/raw/<file>` (serves `text/html`). The
  first load shows a consent page with a `button`; click it with
  `tab.evaluate("document.querySelector('button').click()")`. Alternatives that do **not** work:
  `htmlpreview.github.io` (its CSP kills the external `iframe_api` script, so `YT` stays undefined),
  `api.allorigins.win` (frequently 522), raw gist URLs (served as `text/plain`).
- Host facts (this machine): no `python3`, `node` or `openssl` in PATH; `nix` is present. Start the
  static server from the persistent JS kernel with `Bun.serve({port, fetch})`. Use Brave at
  `/etc/profiles/per-user/davr/bin/brave` via `browser.open({app:{path}})`. The `/nix/store/...chromium-*`
  binary fails to attach over CDP here; do not burn time on it.
- The agent `hub start`/process broker may be dead; drive long processes from the JS kernel instead.

## Player API facts worth re-measuring cheaply

- `start`/`end` are honoured on load; state goes to `0` at exactly `end`. `getDuration()` always
  returns the **full** video length, never the range length.
- `end` does not survive a forward seek past it.
- `loadVideoById({videoId, startSeconds, endSeconds})` is the **only** call taking `endSeconds`
  (object syntax; the positional form ignores it). Cost ≈0.6–1.1 s to playing, with a media re-load.
- `loop=1` needs `playlist=<same id>` and restarts the item at **0**, ignoring `start`; it cannot loop
  a sub-range. The working range loop is a page-side watchdog: on `onStateChange` `data === 0` do
  `seekTo(start, true)` + `playVideo()` — seam ≈0.1 s, no re-load.
- `playsinline` is iOS-only; `modestbranding` is dead; `mute` is not in the documented parameter table
  (use `player.mute()`); `rel=0` only keeps related videos on the same channel.
- Unmuted autoplay without a gesture is refused and reported through `onAutoplayBlocked`; muted works.

## Refusals

- `onError(150)` with `getDuration()` 0 and state stuck at `-1` covers embedding-disabled videos
  (watch page `"playableInEmbed": false`) **and** age-gated videos (watch page text
  "Sign in to confirm your age"), so the classes are not separable in code. `153` means missing
  Referer/identity. Render text lives inside the cross-origin frame and can be captured only as pixels.
- `/oembed` as a server-side oracle: `https://www.youtube.com/oembed?url=<watch url>&format=json` →
  `401` = not embeddable, `200` = embeddable *or* merely age-gated (200 does not promise playback).
- Search-result sampling rarely finds the embedding-disabled class (203 IDs sampled, one hit); use
  `yt-dlp --print "%(id)s|%(playable_in_embed)s" --match-filter "playable_in_embed=False"` to hunt them.

## Harness traps

- `tab.run` has a ~30 s budget and the tab is **busy** while an in-page `await` runs: take screenshots
  from a separate call after a fire-and-forget `tab.evaluate` has kicked the setup off.
- Top-level bindings in the JS kernel are dropped after a cell throws: rebind `globalThis.tab = browser.tab(name)`
  and re-declare helpers instead of assuming they persist.
- Clean up: `browser.close({name})`, `server.stop(true)`; do not leave a public gist holding anything
  but the scratch page.
