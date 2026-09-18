---
name: arm64-brave-browser-verification
description: "Run browser verification (DOM eval, click, snapshot, screenshot) on this arm64 NixOS host when no Chromium exists: point agent-browser at the system Brave via --executable-path, since Chrome for Testing ships no linux/arm64 build and both browser.open and agent-browser auto-launch fail."
---

# Browser verification on this arm64 NixOS host

Both browser drivers fail out of the box here, for the same reason: Chrome for
Testing has no `linux/arm64` build, and no Chromium is installed.

Observed failures:

- `browser.open` → `Failed to install Chromium for puppeteer: Chrome for Testing does not provide linux/arm64 builds. Set PUPPETEER_EXECUTABLE_PATH…`
- `agent_browser_open` with no args → `Auto-launch failed: Chrome not found. Checked: agent-browser cache, System Chrome installations, Puppeteer browser cache, Playwright browser cache.`

## Fix: point the tool at the system Brave

Executable: `/etc/profiles/per-user/da/bin/brave`

On `xd://mcp__agent_browser_*` calls, pass the flag through `extraArgs` — it is
mounted on `open`, `snapshot`, `click`, `eval`, and `screenshot` (checked; the
schema docs list no browser-launch field, so `extraArgs` is the route):

```json
{"url": "http://127.0.0.1:PORT/", "session": "check", "timeoutMs": 60000,
 "extraArgs": ["--executable-path", "/etc/profiles/per-user/da/bin/brave"]}
```

Repeat `extraArgs` on follow-up calls in the same session, not just `open`.

## Traps

- `browser.open` (the eval-tool device) has no executable-path override and
  `env("PUPPETEER_EXECUTABLE_PATH", …)` does not rescue it. Use
  `xd://mcp__agent_browser_*` instead; do not keep retrying `browser.open`.
- `mcp__agent_browser_click` takes `selector` only. A ref goes in as
  `"selector": "@e14"` — a bare `ref` key is rejected with a schema error.
- `mcp__agent_browser_eval` takes `script` as a string of JS. Quote it
  carefully: embed a self-invoking IIFE plus `JSON.stringify(...)` and read the
  result out of `response.result`. A raw `(() => …)()` payload fails to parse.
- Screenshot returned to a text-only model is omitted; route it through
  `read <png>?q=<question>` to get a vision description instead.

## Layout checks: measure, do not trust the first screenshot

The resume page scrolls inside `.flex-1.min-h-0.overflow-y-auto`, and the dock
is `position: fixed` at the viewport bottom (`top 546, height 93` in a 639 px
viewport). A card whose bottom lands under the dock looks clipped in a
screenshot even though nothing is wrong: scroll the inner container, not
`window`, then re-shoot.

```js
// window.scrollBy does nothing; scroll the real container
const sc = document.querySelector('.flex-1.min-h-0.overflow-y-auto');
const card = [...document.querySelectorAll('button.ios-card-header')]
  .find((x) => x.innerText.includes('NAME')).closest('.ios-card');
sc.scrollTop += card.getBoundingClientRect().bottom - 520;
```

Confirm geometry from the DOM before believing a vision model that reports
"clipped by the dock": compare `card.getBoundingClientRect().bottom` with the
fixed dock's `top`.

## Why ground-truth the DOM too

Vision at low zoom misreads adjacent chrome and can miss a wrong icon. Pair the
screenshot with one `eval` that returns the facts: computed `backgroundImage`
of the icon, the SVG's `class` (e.g. `lucide lucide-search`), tag list from
`.ios-tag`, and `a.href` targets.
