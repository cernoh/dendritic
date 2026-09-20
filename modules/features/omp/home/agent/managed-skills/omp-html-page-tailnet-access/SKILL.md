---
name: omp-html-page-tailnet-access
description: "Publish an omp-generated HTML page (grill_form round, render_html output) to a phone over the tailnet from NIXPC: the hardcoded-loopback base trap, an origin-fixing pass-through proxy, the herdr-web preview bridge body-drain blocker, and the tailscale serve repoint. Use when a round or report page must be opened, and submitted, from a phone."
---

# Publishing an omp HTML page (grill_form round) to a phone

Measured on NIXPC 2026-09-19, jjsync wayfinder round 1. The page came from `grill_form` at
`http://127.0.0.1:34801/g/<id>/round/1`.

## The trap that decides everything

The round page **hardcodes its own origin**: `<form id="grill-form"
data-endpoint="http://127.0.0.1:34801/g/<id>/round/1/answers" data-base="http://127.0.0.1:34801/g/<id>">`,
and its script does `fetch(endpoint, …)` and `fetch(base + "/state")`. Prove it is not
Host-derived before designing anything:

```sh
curl -s -H 'Host: nixpc.<tailnet>.ts.net:34801' http://127.0.0.1:34801/g/<id>/round/1 \
  | sed -n 's/.*\(data-endpoint="[^"]*"\).*/\1/p'
```

Any plain reverse proxy — `tailscale serve`, the herdr-web preview bridge — therefore renders
the page but sends every submit and `/state` poll to **the phone's own loopback**. The fix is a
pass-through proxy that strips the literal `http://127.0.0.1:<form-port>` from `text/html`
responses, which turns all page URLs origin-relative.

## The proxy (`/tmp/grill-bridge-proxy.js`, node, no deps)

- Listen on `GRILL_BIND` (default `127.0.0.1`) : `GRILL_PROXY_PORT` (34803).
- Forward every request to `127.0.0.1:GRILL_TARGET_PORT` (34801) with `host` rewritten,
  `accept-encoding` deleted, body piped (`up.end()` for GET/HEAD, `req.pipe(up)` otherwise).
- For `text/html` responses: buffer, `.split('http://127.0.0.1:34801').join('')`, then
  **delete both `content-length` and `transfer-encoding`** before setting the new
  `content-length`. Keeping `transfer-encoding` makes the downstream proxy reject the response
  (`Parse Error: Content-Length can't be present with Transfer-Encoding`, surfaced as a 502).
- Non-HTML responses stream through untouched.

## Starting it here (no hub broker)

`hub op:start` fails on this host: `Failed to start daemon broker … broker.sock` ENOENT. Start
detached instead and confirm the port:

```sh
setsid nohup /nix/store/v6wsd9nyglmwh32yn7w8z11dq9cksg4m-nodejs-24.20.0/bin/node \
  /tmp/grill-bridge-proxy.js > /tmp/grill-proxy.log 2>&1 < /dev/null &
sleep 1; ss -ltn | awk '$4 ~ /:34803$/ {print $4}'
```

`bun`, `node` and `python3` are off PATH; use the store's node as above. Bind the
phone-facing instance to the **tailnet IP**, not `0.0.0.0` (a LAN peer could otherwise read and
submit the form):

```sh
GRILL_BIND=100.x.y.z GRILL_PROXY_PORT=34805 setsid nohup <node> /tmp/grill-bridge-proxy.js &
```

## Two ways to reach the phone

1. **No root**: the listener above is already tailnet-reachable (measured: page 200 and a
   body-carrying POST 200 over `http://100.x.y.z:34805/…`). Hand over the MagicDNS form,
   `http://<host>.<tailnet>.ts.net:34805/g/<id>/round/1`, not the bare IP. Caveat: plain HTTP,
   so a browser's HTTPS-First upgrade can bite.
2. **HTTPS, needs one root line**: `tailscale serve` config is root-only here
   (`sending serve config: Access denied: serve config denied`; `sudo -n` wants a password).
   The mapping must target the **proxy**, not the form server:

   ```sh
   sudo tailscale serve --bg --yes --https=34801 http://127.0.0.1:34803
   ```

   Same command with an existing port **replaces** that handler, so the URL the user already
   has keeps working. Ask for `sudo tailscale set --operator=$USER` once if several rounds are
   expected — after that, mappings can be changed without asking.

## Do not use the herdr-web preview bridge for this

`https://<host>.<tailnet>.ts.net:17930/p/<port>/…` renders the page but **cannot submit**:

- `server.js:204` is `app.use(express.json())`, above the preview middleware at `:288`, so the
  JSON body is drained before `preview.handle` pipes it; the upstream then hangs (measured: 6 s
  timeout, `socket hang up`). No proxy change fixes this.
- Its injected shim rewrites only URLs starting with `/` (`preview.js` `fix()`), and injects
  `<base href="/p/<port>/">`, so the page's hardcoded loopback endpoint survives regardless.
- Enabling a port is `POST http://127.0.0.1:7930/api/preview/enable -d '{"port":<n>}'`; the
  allow-list is in-memory and there is no disable route.

## Verification before handing over a URL

```sh
RID=<round-page-id>
curl -s -m 6 -o /tmp/p.html -w 'page %{http_code} %{size_download}\n' "http://127.0.0.1:34803/g/$RID/round/1"
sed -n 's/.*\(data-endpoint="[^"]*"\).*/\1/p' /tmp/p.html   # expect "/g/<id>/…", not 127.0.0.1
curl -s -m 6 "http://127.0.0.1:34803/g/$RID/state"          # expect {"round":1,"answered":0,…}
curl -s -m 6 -o /dev/null -w 'post %{http_code}\n' -X POST -H 'content-type: application/json' \
  -d '{"answers":{}}' "http://127.0.0.1:34803/g/$RID/round/1"   # 200 = body relayed
curl -sk -m 8 --resolve <host>.<tailnet>.ts.net:34801:100.x.y.z -o /dev/null -w '%{http_code}\n' \
  "https://<host>.<tailnet>.ts.net:34801/g/$RID/round/1"
```

Never POST to the real `/round/<n>/answers` to test: the form server stores it and injects it
as the next user message. A POST to the page route proves the same relay.

The host has no MagicDNS resolution itself, so `curl` the `.ts.net` name with `--resolve`; the
phone resolves it normally.
