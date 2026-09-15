---
name: sandboxed-ui-verification
description: "Verify a web UI from an agent/subagent session when the harness browser prelude times out and hub's process broker is dead: detached preview servers, mounted agent_browser MCP tools, same-origin-iframe viewport measurement, vision QA on screenshots via read \"?q=\", and the fixed-overlay clearance recipe. Use before claiming any browser UI change is verified."
---

# Verifying a web UI without a working harness browser

Conditions this recipe is written for: a remote/headless NixOS box, no `node` on
PATH (node only via `nix shell nixpkgs#nodejs -c ...`), the harness `browser`
prelude failing (`Browser open timed out after 30000ms`), and `hub` refusing to
start servers (`Failed to start daemon broker: connect ENOENT .../broker.sock`).

## 1. Serve the build (detached, bounded)

```sh
cd <worktree> && npm ci && npm run build
setsid nohup nix shell nixpkgs#nodejs -c npx vite preview --port 4190 --strictPort \
  >/tmp/preview-4190.log 2>&1 < /dev/null &
sleep 6; curl -s -o /dev/null -w "preview=%{http_code}\n" http://127.0.0.1:4190/
```

`setsid` + `nohup` survive the tool call. Use a unique port per agent/worktree.
Kill with `pkill -f "vite preview --port 4190"`; verify with `pgrep -af "vite preview" | wc -l` (0) before finishing, and never `pkill` a broad pattern.

## 2. Interactive driver: the mounted agent_browser MCP

Write JSON args to these internal URIs (`{"url": ...}`, `{"script": ...}`, `{"key": ...}`, `{"all": true}`):

- `xd://mcp__agent_browser_open` — returns targetId, title, url
- `xd://mcp__agent_browser_eval` — key MUST be `script`; returns the stringified result
- `xd://mcp__agent_browser_press` / `_click` / `_snapshot` (aria tree with refs) / `_screenshot` / `_close`

Gotchas:
- An `eval` whose base URL is not a real document cannot `fetch('/')` — `Failed to parse URL from /`. Read the DOM instead of fetching.
- The browser is launched once and **reused**; `extraArgs` (e.g. `--window-size`) and `namespace` do NOT resize an already-running browser. Use `{"all": true}` on close, then open with `extraArgs` if you truly need a new window size.
- Static assets are read from disk per request, so rebuilding `dist/` under a running preview is enough — no restart needed.

## 3. Narrow-viewport measurement without viewport control

Build a same-origin iframe at the target width inside `eval`; media queries inside it respond to the iframe width:

```js
(async () => {
  const f = document.createElement('iframe');
  f.style.cssText = 'position:fixed;left:-9999px;top:0;width:375px;height:812px;border:0';
  f.src = '/'; document.body.appendChild(f);
  await new Promise(r => f.onload = r); await new Promise(r => setTimeout(r, 1500));
  const d = f.contentDocument, el = d.documentElement;
  const small = [];
  d.querySelectorAll('a, button').forEach(e => { const r = e.getBoundingClientRect();
    if (r.width < 44 || r.height < 44) small.push([e.tagName, Math.round(r.width), Math.round(r.height)]); });
  return JSON.stringify({ overflow: el.scrollWidth - el.clientWidth, smallTargets: small });
})()
```

Expand every collapsible first (`d.querySelectorAll('.ios-card-header, .ios-list-item').forEach(b => b.click())`) and re-measure — expansion is where overflow and clipping actually appear.

## 4. Fixed-overlay (dock/header) clearance

Scroll the **real** scroll container, not the window — with `h-screen` + `flex-1 overflow-y-auto` the page often does not scroll:

```js
const sc = [...document.querySelectorAll('div')]
  .find(e => e.scrollHeight > e.clientHeight + 4 && getComputedStyle(e).overflowY !== 'visible');
sc.scrollTop = sc.scrollHeight;
// then compare rects: clearance = dock.getBoundingClientRect().top - footer.getBoundingClientRect().bottom
```

Report the number (must be > 0), not a screenshot impression.

## 5. Keyboard / focus

`eval` `el.focus()`, then `xd://mcp__agent_browser_press` with `{"key":"Enter"}` (real key event), then re-`eval` `aria-expanded`, panel presence, and `getComputedStyle(el).outlineWidth/outlineStyle`. Tab-order walks work through repeated `press` + reading `document.activeElement.outerHTML.slice(0,120)`.

## 6. Screenshots, exact width, and vision QA

```sh
nix shell nixpkgs#chromium -c chromium --headless=new --no-sandbox --disable-gpu \
  --hide-scrollbars --virtual-time-budget=8000 --window-size=375,812 \
  --screenshot=/tmp/shot-375.png http://127.0.0.1:4190/
```

Then `read("/tmp/shot-375.png?q=<specific question>")` — a vision model answers without the working model needing image input. Quote answers verbatim as evidence.

**Trust the DOM over the vision report for layout claims.** A vision pass called a `280px 280px 280px` grid "single column" because the screenshot only covered the full-width header above the grid. Confirm with `getComputedStyle(grid).gridTemplateColumns` and the children's rects. Vision is good for "is the badge visible / is anything clipped / is the text legible"; it is unreliable for subtle backgrounds — verify "no text directly on the wallpaper" by reading `getComputedStyle(label).backgroundImage`.

## 7. Closeout

Close the browser (`{"all": true}`), kill every preview server, then
`git worktree list` / `pgrep -af "vite preview"` to prove zero leftovers.

## Related git convention

When a repo requires PR titles to end with the PR's own number, GitHub's squash
merge appends the number again, producing `... (#68) (#68)`. Merge with an
explicit subject instead:

```sh
gh pr merge <N> --squash --delete-branch --subject "<type>(<scope>): <summary> (#<N>)"
```
