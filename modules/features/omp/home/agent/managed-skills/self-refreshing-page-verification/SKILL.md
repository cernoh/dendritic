---
name: self-refreshing-page-verification
description: "Prove a self-refreshing HTML page (dashboard, live view, poll-and-repaint page) actually repaints, without waiting real intervals or trusting a screenshot: expose a DOM poll counter, dump the DOM under Chromium --virtual-time-budget, check node counts for nesting bugs, and pace the interval to the backend API budget."
---

# Verifying a page that refreshes itself

A screenshot shows one paint; it can never show that the page polls and repaints. Verified 2026-09-17 on the `wayfinder_view` dashboard in `cernoh/dendritic` (live HTML view of a GitHub wayfinder map, browser polling `data.json`).

## 1. Make the loop observable from the DOM

Have the page's poll callback record its own progress on the element it repaints:

```js
fetch("data.json", { cache: "no-store" })
  .then((r) => r.json())
  .then((data) => {
    live.innerHTML = data.bodyHtml;
    live.dataset.polls = String(Number(live.dataset.polls || "0") + 1);
    updated.textContent = "updated " + data.updatedAt;
  });
```

A hidden `data-polls` attribute is cheap, harmless in production, and turns an unprovable async loop into a grep.

Do **not** rely on the visible timestamp to prove a repaint: most human-readable stamps truncate to the minute, so a repaint inside the same minute leaves the string identical.

## 2. Observe the loop without waiting

Chromium's virtual time makes the page's timers fire immediately while the real network still runs:

```bash
nix shell nixpkgs#chromium -c chromium --headless=new --no-sandbox --disable-gpu \
  --virtual-time-budget=70000 --dump-dom <url> > dom.html
grep -o 'data-polls="[0-9]*"' dom.html
```

Budget ≈ `interval x (polls wanted + 1)` plus slack. For a 30 s interval, 70000 ms yields `data-polls="2"`. Evidence, not impression.

## 3. Structure check in the same dump

A repaint that writes a fragment containing the container it targets nests a duplicate node. Grep the dump for the container, not the source:

```bash
grep -c 'id="wf-live"' dom.html     # must be 1
```

Fix the shape rather than the symptom: return the **inner** HTML from the renderer, and wrap it once in the page (`<main id="x">${render(body)}</main>`), so `innerHTML` replacement cannot nest.

## 4. Separate server faults from client faults

`curl` the served URL first. If the HTML lacks the content, the bug is server-side and no browser time will help. Only then blame the client and dump the DOM.

## 5. Screenshot for the pixels, the dump for the rest

`--screenshot=out.png` plus a vision question (`read('out.png?q=…')`) is the tool for layout: one-word-per-line wrapping inside a fixed-width grid column, clipped text, overlap. It is not the tool for timers or node counts. A vision pass on the first dashboard build caught a real wrap bug that both the DOM dump and the counts had passed.

## 6. Pace the loop to the backend budget

Count the backend calls one refetch makes before choosing the interval. A fan-out of ~7 `gh api` calls every 5 s is about 5000 calls/hour, which is the whole authenticated GitHub REST budget for one open tab. Default such a page to 30 s, expose an explicit static mode (`poll: 0`), and memoize a request burst for a few seconds so two viewers cannot double the cost.

Keep the timer in the page. A server-side interval in an omp extension violates the extension contract (no timers, no global state); the browser is the right place for the loop, and the handle only needs `unref()` plus a `session_shutdown` close.

## 7. Counts lag the writes

The view is only as fresh as its last fetch. A ticket closed or blocked seconds ago can still show its old state, and GitHub itself needs a few seconds to report a fresh `blocked_by` edge. Say that in the tool description instead of promising instant truth.
