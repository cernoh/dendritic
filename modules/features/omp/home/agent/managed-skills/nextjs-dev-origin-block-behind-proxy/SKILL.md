---
name: nextjs-dev-origin-block-behind-proxy
description: "Diagnose and fix a Next.js 16 dev server that serves HTML but never hydrates when reached through a different origin (herdr-web preview, tailnet reverse proxy, LAN IP, container): the dev-only blockCrossSiteDEV check returns 403 Unauthorized on every /_next/* asset and the HMR socket. Use when a page loads but stays server-rendered/empty (spinner forever), when the console shows 403s on /_next/static chunks, or before configuring allowedDevOrigins."
---

# Next 16 dev server behind another origin: HTML loads, nothing hydrates

## Symptom

- Page HTML 200 through the proxy; visible shell renders (sidebar, headings).
- Client-rendered parts never appear: a component stuck on `Loading…`, no `<textarea>`, empty tables — the server HTML only.
- In-page evidence: `document.querySelectorAll('[class*=__reactFiber]')`/fiber keys absent, React devtools hook present (scripts loaded, hydration never started).
- Healthy-looking API: a page-context `fetch('/api/x')` returns 200 with real data. The data path is innocent.
- Console: 403 (`text/plain`, body literally `Unauthorized`) on `/_next/static/chunks/*`, and `WebSocket ... /_next/hmr ... net::ERR_INVALID_HTTP_RESPONSE`.

## Cause

`next/dist/server/lib/router-utils/block-cross-site-dev.js` → `blockCrossSiteDEV`. Installed only in development (`router-server.js` guards calls with `if (development)`). It reads the request `Origin` (or `Referer`) host and blocks every dev resource unless the host is in:

```
['**.localhost', 'localhost', ...config.allowedDevOrigins] + (opts.hostname if set)
```

`127.0.0.1` is **not** in the default list. So:

- `http://localhost:3000` works.
- `http://127.0.0.1:3000` breaks — and proxies usually connect to `127.0.0.1:PORT` and/or rewrite `Host` while the browser's `Origin` stays the proxy's, so both the LAN-IP and proxy/tailnet origin variants break.

Decisive one-liner (chunk URL from the page's own `script[src]`):

```bash
U=http://127.0.0.1:3000/_next/static/chunks/<chunk>.js
curl -s -o /dev/null -w '%{http_code}\n' "$U"                                  # 200
curl -s -o /dev/null -w '%{http_code}\n' -H 'Origin: http://127.0.0.1:3000' "$U"  # 403, body "Unauthorized"
curl -s -o /dev/null -w '%{http_code}\n' -H 'Origin: http://localhost:3000'    "$U"  # 200
```

## Fix (prefer the ones that change no source)

1. **Local-only work: use `http://localhost:3000`.** Free.
2. **Serve behind a proxy: run production.** The block is dev-only, so `next build` + `next start` on the same port serves `/_next/static` with no origin check. This is the right move for a preview/phone check — you lose HMR, nothing else.
3. **Keep dev + proxy:** only `allowedDevOrigins` in `next.config.mjs` fixes it (add the proxy host, e.g. `127.0.0.1` or `<machine>.<tailnet>.ts.net`), or start dev bound to the host you browse (`next dev -H <host>` pushes that hostname into the allowlist). Both are source/config changes — do not make them in a directory you do not own.

## Traps when switching to production

- `BUILD_DIST=<dir> npm run build` (Next's documented escape hatch for dual dev/prod) writes `.next-prod/types/**/*.ts` into the tracked `tsconfig.json`. Revert it, or build into the default `.next` while no dev server runs — then `git status` stays clean.
- Keep the **same port** if a port-keyed reverse proxy (e.g. herdr-web preview) enabled it: the enable flag is in-memory and keyed by port. Re-`POST /api/preview/enable {"port":N}` after a bridge restart.
- `next start` needs the build's dist dir env var present at start as well as build.

## Verification bar (all read-only, all cheap)

1. Playwright/agent-browser on the direct URL: the component actually mounted (textarea/rows present), not just HTTP 200.
2. Same check through the proxy URL (`/p/<port>/...`).
3. One chunk **and** one API route through the proxy, with the real outer `Origin` header, both 200.
4. A write-path page renders live data (proves reads, not just the shell).
5. `git status` clean for any directory you do not own.

## Playwright-in-Nix notes

- The dev-shell hook pins `playwright-core` to match Nix browsers; if the browser revision skews, pass `executablePath` to the Nix chromium binary instead of fighting the version check.
- A 30s `browser.open` timeout in the harness is not evidence: fall back to the mounted `agent_browser_*` tools, whose `eval` takes a **JSON args object** (`{"script": "(async () => {...})()"}`), not a bare function body.
