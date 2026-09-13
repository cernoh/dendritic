---
name: screenshot-pixel-verification
description: "Ground-truth visual QA when matching a web UI to a reference screenshot: decode PNGs (incl. palette/ct-3) in Bun, sample region colors with rounded coordinates, verify claims vision models make at low zoom, and avoid stale-cache/broken-A/B traps"
---

# Screenshot Pixel Verification

Use when matching a rendered web page against a reference screenshot (porting a mobile app to web, visual QA of UI changes) and vision-model answers disagree, look confabulated, or claim details invisible at low zoom.

## Workflow
1. **Capture the render** at a phone viewport with a real browser, e.g. `page.setViewport({ width: 390, height: 780, deviceScaleFactor: 3 })`, screenshot to PNG.
2. **Vision reads are hypotheses, not proof.** Zoomed crops (5–12× via `ffmpeg -i in.png -vf "crop=W:H:X:Y,scale=iw*8:ih*8:flags=lanczos" out.png`) give reliable shape reads. Whole-image or ≤390px-wide reads confabulate: they will "see" icons that pixel data disproves (e.g. a bell from a status-bar battery above a dot) and miss small drawings (call a correct 26px tram "broken dashes"). Verify every contested claim by sampling pixels.
3. **Pixel-sample deterministically** in Bun/JS:
   - Palette PNGs report color type 3 — MUST parse `PLTE` and map indices to RGB before sampling; treating bytes as RGB yields near-black noise.
   - Always `Math.round()` coordinates before indexing `px[y*stride + x*ch]`; float indices silently return `undefined` → every count is 0 and looks like "nothing rendered".
   - Lossy screenshots (webp→png conversions) shift colors: compare by family (e.g. `g>r+15 && g>b+60 && b<120` for lime) or generous tolerance (±30–40), not exact hex, unless the source PNG is lossless.
4. **Build A/B comparisons at matched CSS scale.** Downscaling one side to half the other's width makes it look "compressed / tiny fonts / missing icons" — artifacts only. Align both to the same CSS width before comparing.
5. **Iteration against a service worker cache:** reloads serve stale assets. Clear caches + unregister (`caches.keys() → delete`, `getRegistrations() → unregister`) AND disable the HTTP cache via CDP (`Network.setCacheDisabled`) before re-measuring; verify with a DOM probe (`getBoundingClientRect` of changed elements) that the new version is live.
6. **Check icon sprites with `getBBox()`** on the `<use>` elements (external `sprite.svg#id` refs resolve; bbox equals the symbol geometry) — a cheap no-screenshot proof that references resolve.

## Ground truth hierarchy
Raw pixel data (correctly decoded) > zoomed-crop vision reads > whole-image vision reads. When they conflict, trust the pixels and say so with the numbers.
