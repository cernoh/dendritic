---
name: verify-generated-html-artifact
description: "Prove a generated self-contained HTML page (omp render_html output, exported report, gallery) is correct and themed, without a server: agent-browser MCP instead of brave --headless, computed-CSS assertions instead of pixel sampling, and vision QA of screenshots through read \"?q=\"."
---

# Verifying a generated HTML artifact

For a static, self-contained HTML file written by a tool or an extension (for
example the `render_html` tool of `html-report.ts`). No server, no app: the file
is the deliverable, so the proof is the rendered page plus its computed values.

## Browser: which one actually works here

- `brave --headless=new --screenshot=... --user-data-dir=...` HANGS on this host
  (verified 2026-09-15: `--dump-dom` and `--screenshot` both produced nothing
  before a 120 s timeout, exit 0 with no file). Do not start there.
- `browser.open(...)` from the omp harness fails with `Shared browser daemon
  unavailable (broker start or Chromium launch failed)` when the broker is down.
- The `agent-browser` CLI and its mounted MCP tools work: their own Chromium
  launches on demand.

```text
mcp__agent_browser_open    { "url": "file:///tmp/page.html" }
mcp__agent_browser_eval    { "script": "(() => ...)()" }      # param is `script`, not `code`
mcp__agent_browser_screenshot { "path": "/tmp/shot.png", "fullPage": true }
mcp__agent_browser_close   {}
```

Close the session when done: it holds a browser process.

## Assert computed values, not pixels

Pixel sampling of a screenshot is the weak proof. `getComputedStyle` returns the
exact value the browser applied, and a CSS custom property resolves to the
scheme hex:

```js
(() => {
  const root = document.documentElement;
  const cs = getComputedStyle(root);
  const q = document.querySelector("article.q");
  return JSON.stringify({
    theme: root.dataset.theme,
    themes: root.dataset.themes,
    bg: getComputedStyle(document.body).backgroundColor,   // rgb(30, 24, 19)
    accent: cs.getPropertyValue("--accent").trim(),        // #c99a5b
    cardBg: q ? getComputedStyle(q).backgroundColor : null,
    buttons: Array.from(document.querySelectorAll(".theme-switch button"))
      .map((b) => b.textContent + (b.classList.contains("active") ? "*" : "")),
  });
})()
```

Then compare the numbers against the source of truth, for example
`nix eval --json .#scheme.html` or `~/.omp/agent/html-theme.json`:
`rgb(30, 24, 19)` = `#1e1813` = `palette.base`; `#c99a5b` = `palette.primary`.

Test a theme switcher by clicking inside the same eval and snapping after each
click, so one call proves every state plus persistence:

```js
const click = (id) => document.querySelector(`.theme-switch button[data-theme-id="${id}"]`).click();
```

## Vision QA only for the questions that need eyes

The capture turn's model may not accept image input ("the active model does not
support image input"), so read the PNG with a question:

```text
read /tmp/shot.png?q=Describe this page: background, text colour, header, and whether any element looks broken.
```

That answers layout and readability, not values. Use one read per theme.

## Checklist

1. `agent_browser_open` the `file://` URL; confirm the title.
2. `agent_browser_eval` the computed-value script; compare to the palette JSON.
3. `agent_browser_screenshot`; `read` it with `?q=` for a layout opinion.
4. Grep the file for self-containment: no `<link>`, no `<script src>`, no
   `<img src="http`, and the injection guard (`href="#"` for a `javascript:` URL).
5. `agent_browser_close`.
