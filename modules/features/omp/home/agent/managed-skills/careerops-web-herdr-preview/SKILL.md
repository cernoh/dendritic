---
name: careerops-web-herdr-preview
description: "Run the career-ops web/ Next.js dev server headlessly and expose it through the herdr-web bridge preview (port enable + /p/port/ proxy), including the flake dev shell, the dead-hub-broker detached start, and the loopback Host rewrite that makes the API origin guard pass."
---

Serve the career-ops `web/` app and open it in herdr-web. Run only — never edit `web/` (control-file owned) or the user layer.

## Facts that shape the steps

- `node` is not on PATH in the pane; it lives in the repo flake dev shell (`flake.nix` devShell: `nodejs`, `bun`, playwright browsers + `PLAYWRIGHT_*` env).
- The herdr-web bridge (`herdr-web` binary, `127.0.0.1:7930`, usually also tailnet `:17930`) has an **integrated browser**: it reverse-proxies a local dev server under its own origin at `/p/<port>/…` and shows it in an iframe. Real page, real text, phone pinch-zoom — not a pixel stream.
- Proxying is **opt-in per port** (`preview.allow()` in herdr-web `lib/preview.js`); a non-enabled port returns `403 port N is not enabled for preview`.
- `preview.js` rewrites `Host` to `127.0.0.1:<port>` before forwarding, so career-ops' `web/src/lib/origin-guard.mjs` **host layer passes** for API calls through the bridge. An iframe under the bridge origin is same-origin, so the Fetch-Metadata layer passes too. No `CAREER_OPS_WEB_ALLOWED_HOSTS` needed.
- The hub broker is often dead (`Failed to start daemon broker … connect ENOENT`). Do not fight it: start the server detached instead.

## Steps

1. Confirm the bridge is up and nothing holds the port:
   ```bash
   pgrep -af herdr-web | cut -c1-160        # bridge, if absent start it / let the herdr plugin start it
   ss -ltn | grep -E ':3000' || echo "3000 free"
   ```
2. Install deps inside the flake shell (node 24.x here; `web/` has its own lockfile, so `npm ci` is the documented path in `web/README.md`):
   ```bash
   cd /mnt/2tb-ext4/careerops/web
   nix develop .. -c bash -lc 'npm ci'
   ```
   The devShell `shellHook` then repins `playwright@<nixpkgs version>` with `npm install --no-save` on each shell entry — expected, not a fault.
3. Start detached (survives the session; `setsid` so it is its own process group):
   ```bash
   cd /mnt/2tb-ext4/careerops/web
   setsid nohup nix develop /mnt/2tb-ext4/careerops -c npm run dev \
     > /tmp/careerops-web.log 2>&1 < /dev/null & disown
   sleep 25; ss -ltn | grep ':3000'
   ```
   `read` `/tmp/careerops-web.log` for `✓ Ready in …` (the bash tool blocks `tail`/`head`/`cat`).
4. Enable the port for preview, then prove the proxy path (both calls, in this order):
   ```bash
   curl -s -X POST http://127.0.0.1:7930/api/preview/enable \
     -H 'content-type: application/json' -d '{"port":3000}'      # -> {"ok":true,"port":3000}
   curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:7930/p/3000/
   ```
5. Verify the port is discovered and ranked dev-first:
   ```bash
   nu -c '^curl -s http://127.0.0.1:7930/api/ports | from json | get ports | first 8 | to md --pretty'
   ```
   The schema is `{port, process}` **only** — there is no `score` column; asking for it errors `column_not_found`. `next-server` shows as `next-server (v1` (name truncated at whitespace).
6. Route sanity check through the bridge. Real routes are `/`, `/actions`, `/analytics`, `/apply`, `/config`, `/cv`, `/explore`, `/followups`, `/jobs`, `/pipeline`, `/portals` — **`web/README.md`'s "Today" page is stale, `/today` 404s**.
7. Tell the user to tap the **3000** entry in herdr-web.

## Caveats

- The preview enable flag is in-memory: a bridge restart needs step 4 again.
- Stop with the process group, not the child pid: `kill -TERM -<PGID of the setsid leader>` (find it via `ps -o pid,ppid,pgid,sid,cmd -p <next-dev-pid>`; the `next dev` child's PGID is the `nix develop` leader).
- An `http://localhost:PORT` string in agent/pane output is itself a tap target in herdr-web, so printing the URL is enough to make it reachable.
