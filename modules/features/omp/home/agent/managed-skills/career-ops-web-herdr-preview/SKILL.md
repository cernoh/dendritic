---
name: career-ops-web-herdr-preview
description: "Run and check the career-ops Next.js web app through the herdr-web preview bridge: Next 16 dev blocks /_next/* from non-localhost origins (use a production start), ports must be enabled via /api/preview/enable, unprefixed app paths route only by Referer, and why the \"View tailored CV\" link and company-slug matching fail."
---

# Serving career-ops web to herdr-web

Repo: `careerops` fork (`/mnt/2tb-ext4/careerops`), app in `web/`. Bridge: `herdr-web` on
`127.0.0.1:7930`, exposed `https://<host>.<tailnet>.ts.net:17930` via `tailscale serve`.
`web/` is a separate track: read/run it, do not edit it.

## Start the server (no hub broker on this host)

```bash
# node comes only from the flake dev shell; deps: cd web && nix develop .. -c bash -lc 'npm ci'
cd /mnt/2tb-ext4/careerops/web
setsid nohup nix develop /mnt/2tb-ext4/careerops -c npm run start > /tmp/careerops-web-prod.log 2>&1 < /dev/null &
```

- `next dev` is the wrong vehicle here. Next 16.3.3 `blockCrossSiteDEV`
  (`next/dist/server/lib/router-utils/block-cross-site-dev.js`, dev-only) allowlists
  `localhost`, `**.localhost`, `allowedDevOrigins`, and the server hostname. A browser at
  `127.0.0.1:3000` sends `Origin: http://127.0.0.1:3000` on chunk/HMR requests → **403
  `Unauthorized`** (plain text, chunked, no other headers) → React never hydrates → server
  HTML only, page stuck on `Loading…`. `/api/*` still 200s, so the data path looks fine.
  Test the mechanism: `curl -H 'Origin: http://127.0.0.1:3000' <chunk-url>` → 403;
  `Origin: http://localhost:3000` → 200.
- Production `next start` has no such gate and serves `/_next/static` from any Origin.
  Build into the **default** `.next`. A custom distDir (`BUILD_DIST=.next-prod`) makes
  `next build` append `.next-prod/types/**/*.ts` to the tracked `web/tsconfig.json` — a
  Next side effect that dirties a file you must not edit. Build default, then
  `git status --short -- web` must be clean.
- Verify: `curl -o /dev/null -w '%{http_code}' http://127.0.0.1:3000/`, then a real browser
  check that a client component mounted (see below).

## Reach it through the bridge

- Enable the port (once per bridge process, in-memory):
  `curl -X POST http://127.0.0.1:7930/api/preview/enable -H 'content-type: application/json' -d '{"port":3000}'`
  then `GET /api/ports` — 3000 ranks first, identified as `next-server`.
- `preview.js` reverse-proxies `/p/<port>/<path>` and rewrites `host` to `127.0.0.1:<port>`,
  so the app's loopback Host guard passes; a page fetch is same-origin → `Sec-Fetch-Site:
  same-origin` passes too.
- Unprefixed app paths (`/api/...`) route **only** by the Referer's `/p/<port>/` prefix.
  A typed or bookmark-reopened root path has no Referer → Express `Cannot GET /api/...`
  (404 HTML). Always give the user the `/p/3000/`-prefixed URL.
- Tailscale HTTPS needs SNI: `curl -sk --resolve <host>:17930:<tailnet-ip> https://<host>:17930/...`
  (connecting by IP fails with a TLS internal-error alert).

## Verify a page actually hydrates

`curl` 200s prove nothing about hydration. Use the mounted `agent_browser` tools and check
for a mounted component, e.g. the CV editor's textarea:

```
open http://127.0.0.1:7930/p/3000/cv
eval: textareas=document.querySelectorAll('textarea').length, value length, "Loading" in body
```

`textareas: 0` + `Loading…` = no hydration. Capture console/network errors with a throwaway
Playwright script run inside the flake shell (`module`/`require` resolution: import
`playwright-core` through `createRequire('/mnt/2tb-ext4/careerops/web/')`; pin the executable
with `executablePath` to the Nix store's `chromium-1208/chrome-linux64/chrome`, since web's
`playwright-core` 1.62 wants a revision the store does not have). Root `playwright` is
1.58.2 and matches rev 1208, so the repo's own CLI (`generate-pdf.mjs`) launches fine.

## "View tailored CV" / can't open a personalised CV

Two independent causes; check both.

1. **Unkeyed manifest.** `web/src/app/api/cv-pdf/route.ts` prefers `?n=<report>` →
   `data/pdf-index.tsv`, then falls back to `?company=` → `companySlug` +
   `matchesTailoredCv`. Rows are keyed only when the PDF was rendered with `--report=NNN`
   (single) or per-entry `reportNum` (batch) — without it the row is written "just unkeyed"
   (empty first column). The company fallback matches the slug as a **whole token**, and the
   loose "first token" fallback was deliberately removed (`cv-match.mjs`, PR #2156), so
   `companySlug("Boots UK") = boots-uk` never matches `cv-davincey-boots-*.pdf`, and a
   non-ASCII name (`Yü Energy`) slugs away from the ASCII filename.
   Symptom matrix: `?company=boots` 200, `?company=Boots%20UK` 404
   `no tailored CV found for this offer`, `?n=1&company=Boots%20UK` 404.
   Repair is the CLI's own writer, not a hand edit:
   `nix develop . -c node generate-pdf.mjs --batch=<manifest> --format=a4` from the repo
   root, with `{input, output, reportNum}` per CV (`output/cv-*.html` → `output/cv-*.pdf`).
   The manifest must live **inside** the workspace (a `/tmp` manifest is rejected:
   "batch manifest escapes the tracker workspace"); a repo-root dotfile works, then delete
   it and its `.results.json`. `updatePDFManifest` drops same-path rows and appends keyed
   ones, so re-running is idempotent. Re-renders keep size and page count but change
   SHA-256 (embedded timestamps) — say so. After: `?n=<n>&company=<anything>` 200s and the
   apply path `?application=<tracker#>` 200s.
2. **Link shape (web/ only).** `web/src/components/generate-pdf-button.tsx` emits
   `<a href="/api/cv-pdf?...n&company" target="_blank" rel="noreferrer">`. Behind the bridge
   the new tab lands on the unprefixed root path with the Referer suppressed → bridge 404
   `Cannot GET /api/cv-pdf` even though the same URL with a `Referer: .../p/3000/...`
   returns the PDF. Proof: an identical synthetic anchor **without** `rel` delivers the PDF
   (the tab title becomes the PDF's own title). Fix belongs in `web/` (drop `rel`, or emit a
   prefix-aware URL); the workaround is the prefixed URL.

`data/`, `output/`, and `web/` are must-not-touch lanes: prefer pointing the user at the
app's own Generate flow or the CLI, and state clearly what was re-written.
