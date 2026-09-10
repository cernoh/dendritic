---
name: webkitgtk-webdriver-probe
description: "Drive the WebKitGTK engine (WebKitWebDriver + MiniBrowser, W3C HTTP) on NixOS to probe page fetches/CORS/loopback behavior when Chrome/CDP is unavailable. Covers binary locations, GIO/TLS env, session creation, and representative results."
---

# Drive WebKitGTK via WebKitWebDriver + MiniBrowser on NixOS

Use when you must test page behavior in the exact WebKitGTK engine
(identical to deno-desktop / webview apps) but Chrome/CDP is unavailable
or wrong, e.g. probing loopback/mixed-content fetches, CORS, or the
"Streaming server is not available" pairing issue.

## Locate binaries (nix store, per ABI)

- Driver: `<webkitgtk>/bin/WebKitWebDriver` (the 6.0 store dir for GTK4
  webview apps like deno laufey; 4.1 for others).
- Browser: `<webkitgtk>/libexec/webkitgtk-6.0/MiniBrowser` (NOT in `bin/`).
- Driver discovers MiniBrowser via its own prefix, same store.

## Environment (the 80% failure cause)

Copy the env of the running target app when possible
(`tr '\0' '\n' < /proc/<pid>/environ`):

- `LD_LIBRARY_PATH` — full rpath list of a working app bundle, e.g.
  `patchelf --print-rpath <bundle>.so`, plus the matching
  `<webkitgtk>/lib`.
- `GIO_EXTRA_MODULES=<glib-networking>/lib/gio/modules:…` — missing →
  page body is exactly `TLS support is not available`.
- `WEBKIT_DISABLE_DMABUF_RENDERER=1` on MangoWM.

Start the driver with that env:

```sh
<nix>/WebKitWebDriver --port=9515 &
curl -s http://127.0.0.1:9515/status   # {"value":{"ready":true,…}}
```

## W3C session (plain HTTP, no client lib needed)

```sh
# create session -> capture sessionId
curl -s -X POST http://127.0.0.1:9515/session -H 'Content-Type: application/json' \
  -d '{"capabilities":{"alwaysMatch":{"browserName":"MiniBrowser"}}}'
# navigate (MiniBrowser window appears on the active Wayland display)
curl -s -X POST http://127.0.0.1:9515/session/$SID/url -H 'Content-Type: application/json' \
  -d '{"url":"https://example.com/"}'
# wait ~10-15s for SPAs/wasm cores, then probe
curl -s -X POST http://127.0.0.1:9515/session/$SID/execute/async -H 'Content-Type: application/json' \
  -d '{"script":"const done=arguments[arguments.length-1]; (async()=>{ try { const r=await fetch(\"http://127.0.0.1:11470/settings\"); done(\"OK \"+r.status); } catch(e){ done(\"FAIL \"+e.message); } })();","args":[]}'
curl -s -X POST http://127.0.0.1:9515/session/$SID/execute/sync -H 'Content-Type: application/json' \
  -d '{"script":"return document.body.innerText;","args":[]}'
```

Gotchas:
- `execute/sync` script must be an expression; `async` needs
  `execute/async` + `arguments[arguments.length-1]` callback.
- Fresh profile = anonymous session; logged-in state of the real app
  lives in ITS webkit storage, not MiniBrowser.
- If a page fetch "succeeds" only on a WebKit error page (TLS missing),
  the result is not representative — fix GIO first.

## Cleanup

`pkill -f 'MiniBrowser --automation'`; kill the driver pid.

## Known result pattern (stremio pairing)

In real page content WebKitGTK blocks `fetch(http://127.0.0.1:11470/…)`
from `https://…` pages ("Load failed", mixed content) while
`https://127-0-0-1.<uuid>.stremio.rocks:12470/…` succeeds — the https
leg of the stremio engine is the pairing path.
