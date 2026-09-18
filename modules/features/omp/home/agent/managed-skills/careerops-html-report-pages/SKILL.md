---
name: careerops-html-report-pages
description: "Render career-ops reports/*.md as HTML pages inside the fork-local viewer (.omp/skills/career-ops-html/render.mjs): the derived-view design, a dependency-free markdown renderer, the untrusted-job-posting content boundary (escaping + link-scheme allowlist), the --watch self-trigger loop, and the fixture-based verification recipe. Use when asked to make reports readable in a browser, when adding a section to the rendered report pages, or when report links 404 or render as raw markdown."
---

# career-ops HTML report pages

Turns `reports/*.md` into readable pages under `output/html/reports/`, reachable
from the **Report** column of the pipeline table and the Reports section.

Companion skills: `careerops-html-viewer-link-paths` (why bare repo-relative
hrefs 404 from `output/html/`), `careerops-html-live-feed` (the activity panel),
`career-ops-html-viewer` (installing/serving the viewer at all).

## The design, and why

- **Markdown stays the source of truth.** `reports/*.md` is user layer and is
  never written by the viewer. The HTML is a derived view, regenerated on every
  build, so an edit to a report and a rebuild is the whole update path.
- **`output/html/` is the only writable directory.** The viewer's own contract.
- **Zero dependencies, self-contained.** No CDN, no build step, no bundled
  markdown library — the repro must work offline and inside a Nix dev shell.
- Report pages are print-friendly on purpose: users print-to-PDF a report to
  read it on a phone, so avoid `break-inside` on table rows and keep `@media
  print` from dropping content.

## Structure

```js
const REPORT_DIR = 'reports';                       // single source of truth for the output dir
const reportPage = (file) => `${REPORT_DIR}/${basename(file).replace(/\.md$/, '.html')}`;
function renderReportPage(name, md) { /* shell + mdToHtml(md) */ }
function mdToHtml(md) { /* block level */ }
function mdInline(s)  { /* escaping, then inline rules */ }
function reportLink(url) { /* scheme boundary, .md → .html */ }
```

`build()` writes the index, then loops `data.reports` writing one page each, and
returns `{ bytes, reports }` — update the call site, which previously used a bare
length.

## Renderer rules that matter

- **Escape first, add tags second.** `mdInline` runs `esc()` before inserting any
  markup, so every tag in the output is ours.
- **Protect code spans before other inline rules**, then restore them by index —
  otherwise `**` inside backticks becomes bold.
- **Metadata runs need `<br>`.** Consecutive lines each matching
  `/^\*\*[^*]+:\*\*/` joined with a space collapse a report's `**Date:**` /
  `**Score:**` header block into one paragraph. Join those with `<br>`;
  any other paragraph joins with a space.
- **Nested lists by indent depth** (`indent >> 1`, clamped): emit the opening or
  closing `<ul>` only when the level changes, and close the remainder at the end.
  A naive per-item emit produces unbalanced tags.
- **Fenced blocks win over everything.** Check `^```` before headings, or a JD
  archive containing `# Heading` and `| pipes |` becomes live markup.

## Untrusted content is the real risk

Reports embed **verbatim job-posting text**, which is untrusted external input.
Two boundaries are mandatory, and both are cheap to verify:

1. **Escaping** — a posting containing `<script>` or `<img onerror=…>` must land
   as visible text, never live markup. Never emit a report page containing a
   `<script>` tag at all.
2. **Link schemes** — an allowlist, not a denylist. Anything whose scheme is not
   `http`/`https`/`mailto` is replaced with `#`, so `[click](javascript:…)` and
   `data:text/html,…` cannot become live links. Bare relative links are fine;
   only a link ending `.md` under `reports/` is retargeted to its `.html` sibling.

Also check for HTML injection per request: bulk and per-store, plus field
granularity, are separate questions.

## The `--watch` self-trigger loop

`build()` writes under `dirname(OUT)`, which lives inside the watched `output/`
tree. A recursive watcher therefore triggers itself and rebuilds forever —
worse now that it writes several more files per run. Guard the watcher callback:

```js
const OUT_DIR = dirname(OUT) + sep;
watch(p, { recursive: true }, (_event, filename) => {
  if (filename && resolve(p, filename.toString()).startsWith(OUT_DIR)) return;
  build();
});
```

## Verification recipe

A throwaway fixture in `reports/` exercises the real code path end to end:

1. Write `reports/999-fixture-renderer-test.md` covering: `<script>` and `<img>`
   probes, `javascript:` and `data:` links, a safe `https` link, a
   `../reports/*.md` sibling link, nested and ordered lists, a blockquote, a hard
   break (two trailing spaces), `---`, an aligned table, and a fence containing
   `**not bold**` and a pipe row.
2. `node .omp/skills/career-ops-html/render.mjs`, then assert on the emitted
   HTML: no `<script>`, escaped probes present, no `href="javascript:"`, safe
   link kept, sibling retargeted, `<ul>` count ≥ 2, `<blockquote>`, `<br>`,
   `<hr>`, `text-align:center`/`:right`, and the fence contents literal.
3. **Delete the fixture and its generated page, rebuild, and re-run
   `verify-pipeline.mjs`** — a stray `.md` in `reports/` is an orphan report and
   pollutes the health check.

Then browser-verify the real pages: fetch every non-http href on the index and
assert 200, open one report page and assert `document.contentType === 'text/html'`
with section headings and a populated `<table>`, and check the visible text
contains no `**`, no `^##`, and no `|---` — leaked markdown is the failure mode a
structural count will not catch.

## Gates before claiming done

```bash
nix develop --command npm run lint                    # 699 .mjs files, after every render.mjs edit
nix develop --command node validate-system-paths-coverage.mjs
node verify-pipeline.mjs
git status --porcelain                                # expect only ?? .omp/
```

Lint must run **after** the last edit — it is easy to run it once and then keep
editing the emitted-script templates.
