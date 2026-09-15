---
name: careerops-html-viewer-link-paths
description: "Diagnose and fix unreachable reports, CVs or JDs in the career-ops HTML viewer (.omp/skills/career-ops-html/render.mjs): the page is written to output/html/ but embeds repo-root-relative hrefs, so the browser resolves them to /output/html/reports/... and every link 404s. Use when the user says they cannot open the reports, when in-page links 404, or after adding a new link to the viewer."
---

# career-ops HTML viewer — link paths

Symptom: the page renders, the tables are populated, but every link to a
report, CV, cover letter or archived JD lands on a 404. The user reports "I
can't access the reports."

## Root cause

`render.mjs` writes the page to `output/html/index.html`, two directories below
the repo root, but it emits repo-root-relative hrefs:

```html
<a href="reports/001-boots-2026-09-15.md">   <!-- WRONG -->
```

The browser resolves a relative href against the **page's own URL**, not the
repo root, so it becomes `/output/html/reports/...` — 404. The `./data/…` and
`./output/…` link families fail the same way. This is pre-existing in the skill
and stays invisible until there is something to click.

Reproduce before changing anything (the two differ by exactly the extra depth):

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4321/output/html/reports/001-boots-2026-09-15.md  # 404
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:4321/reports/001-boots-2026-09-15.md              # 200
```

## Fix

Derive the prefix from `--out`, never hardcode it — a custom `--out` at a
different depth must keep working, over HTTP and from `file://`:

```js
import { relative, sep, posix } from 'path';

const LINK_PREFIX = (() => {
  const rel = relative(dirname(OUT), ROOT).split(sep).join('/');
  return rel === '' ? '' : rel + '/';
})();

/** Resolve a repo-relative path, or a markdown link relative to data/, to a page-safe href. */
function href(...parts) {
  const p = posix.normalize(parts.filter(Boolean).join('/')).replace(/^\.\//, '');
  return LINK_PREFIX + p;
}
```

Route **every** internal link through `href()`. Keep `collect()`'s
`rel: 'output/' + name` fields — they are the inputs; `href()` is the single
place that makes them page-safe.

The tracker's own report cell is a markdown link written relative to `data/`
(`[001](../reports/001-foo.md)`). Resolve it against `data/` so `posix.normalize`
collapses the `../`:

```js
function reportHref(cell) {
  const m = /\]\(([^)]+)\)/.exec(String(cell || ''));
  if (!m) return null;
  const target = m[1].trim();
  if (/^https?:\/\//i.test(target)) return target;   // external links stay untouched
  return href('data', target);
}
```

Leave absolute external hrefs alone: posting URLs (`j.url`), LinkedIn
(`linkedinHref()`), and `mailto:`.

## Verification

The invariant, checked against the **generated file** rather than the intent —
this catches a new link site that forgets `href()`:

```bash
node -e "
const h = require('fs').readFileSync('output/html/index.html','utf8');
const local = [...new Set([...h.matchAll(/href=\"([^\"]+)\"/g)].map(m=>m[1]))]
  .filter(u => !u.startsWith('http') && !u.startsWith('#') && !u.startsWith('mailto:'));
const bad = local.filter(u => !u.startsWith('../../'));
console.log('local:', local.length, 'unprefixed:', bad.length, bad.join(' '));
console.log(bad.length ? 'FAIL: these 404 from /output/html/' : 'PASS');
"
```

Then prove it end to end in the browser — resolving each anchor against
`location.href` is what the click actually does, so a raw `curl` of the literal
href is not equivalent:

```js
(async () => {
  const out = [];
  for (const h of new Set([...document.querySelectorAll('a[href]')]
      .map(a => a.getAttribute('href'))
      .filter(h => h && !h.startsWith('http') && !h.startsWith('#')))) {
    const r = await fetch(new URL(h, location.href));
    out.push([h, r.status]);
  }
  return out;
})()
```

All must be 200. Finally open one report directly and assert the body actually
renders (the user's real complaint is access, not the status code):

```js
({ type: document.contentType, chars: document.body.innerText.length,
   starts: document.body.innerText.slice(0, 60) })
```

A report serves as `text/plain` and should report tens of thousands of
characters beginning with the report heading.

## Anchor audit

Before closing out, list every interpolation in `render.mjs` and confirm each
one is external or wrapped:

```bash
grep -n 'href="\${' .omp/skills/career-ops-html/render.mjs
```

Expect only `href(...)`, `reportHref(...)`, `linkedinHref(...)`, `mailto:`, or
an absolute `j.url`.
