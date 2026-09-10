---
name: stremio-accru-webui-engine-pairing-debug
description: "Diagnose \"Streaming server is not available\" in the stremio-accru webui/engine pairing: mixed-content block of http://127.0.0.1:11470 from https webui, https leg 12470, WebKitGTK WebDriver probing, webview localStorage inspection"
---

# stremio-accru webui ↔ engine pairing debug

Use when the accru app (deno desktop webview) shows "Streaming server is not available"
or the engine "tries to link itself to http://127.0.0.1:11470/" while server.js is up.

## Established root cause (2026-09-09, engine 4.20.15 community + 4.21.0 official both tested)

- webui core (stremio-core WASM) fetches `profile.settings.streamingServerUrl` + `/settings`
  from the `https://web.stremio.com` page. Default = `http://127.0.0.1:11470/`.
- **Mixed content**: real page context (WebKitGTK 2.52.6 AND Chromium) BLOCKS
  `fetch('http://127.0.0.1:11470/settings')` → settings never `Ready` → banner.
  Firefox allows loopback http → community flow works in Firefox, fails in webview engines.
- **Fix leg**: engine HTTPS endpoint `https://127-0-0-1.<uuid>.stremio.rocks:12470/`
  (Let's Encrypt public cert from `~/.stremio-server/httpsCert.json`, `.domain` field)
  serves the same API, fetchable from the https page (verified OK 200).
- Engine version is NOT the cause: official stremio-service v0.1.22 ships server.js 4.21.0,
  community baseline 4.20.15; `/settings` shape identical, no version gate in
  `Stremio/stremio-core` `models/streaming_server.rs` (Ready = fetch+deserialize ok).
- Webui accepts a custom server URL two ways: URL param
  `https://web.stremio.com/?streamingServer=<https-leg-url>` (opens a Confirm modal if the
  URL is not in the saved list — user must click Confirm), or Settings → Streaming →
  override URL. `streamingServer` param == DEFAULT urls applies silently.

## Live-state checks (bash, no sudo)

```bash
ss -tlnp | grep -E ':11470|:12470'            # engine listening?
curl -s http://127.0.0.1:11470/settings | jq -r '.values.serverVersion, .baseUrl'
# https leg (needs uuid from cert): uuid=$(jq -r '.domain' ~/.stremio-server/httpsCert.json)
curl -s https://$uuid:12470/settings | jq -r '.values.serverVersion'   # expect 200, no -k needed
curl -s -m 3 -o /dev/null -w '%{http_code}\n' https://web.stremio.com/  # webui reachable?
```

## Webview session state (user's logged-in profile)

WebKitGTK webview storage for the accru app:
`~/.local/share/stremio-accru/localstorage/https_web.stremio.com_0.localstorage` (SQLite+WAL).
Values are UTF-16LE; decode with sqlite3 `quote()` → xxd -r -p → iconv:

```bash
SRC=~/.local/share/stremio-accru/localstorage
cp "$SRC/https_web.stremio.com_0.localstorage" /tmp/ls.db
cp "$SRC/https_web.stremio.com_0.localstorage-wal" /tmp/ls.db-wal
sqlite3 /tmp/ls.db "select key,length(value) from ItemTable;"
sqlite3 /tmp/ls.db "select quote(value) from ItemTable where key='profile';" \
 | sed "s/^X'//;s/\$//" | xxd -r -p | iconv -f UTF-16LE -t UTF-8 | jq '.settings.streamingServerUrl'
```
Do not write the live DB — WebKit holds it in memory and will overwrite.

## Reproduce in the exact webview engine (WebKitGTK)

Headless Firefox on this NixOS breaks (NSS_3.113 mismatch); scrapling sandbox has no
loopback; agent-browser needs Chrome patched for NixOS (patchelf interpreter+rpath copied
from an already-patched binary, e.g. the accru bundle `.so`). For WebKitGTK itself:

```bash
# WebKitWebDriver + MiniBrowser (same 2.52.6 engine as the deno webview backend):
# 1. launch driver with the accru app's own env (TLS modules matter!):
tr '\0' '\n' < /proc/<accru-pid>/environ > /tmp/env; source-style export GIO_EXTRA_MODULES + LD_LIBRARY_PATH from it
/nix/store/glvd2r8dlhac81vkgjapp1zcs4bbdzq6-webkitgtk-2.52.6+abi=6.0/bin/WebKitWebDriver --port=9515 &
# 2. W3C WebDriver over HTTP (MiniBrowser auto-discovered in libexec/webkitgtk-6.0):
curl -X POST :9515/session -d '{"capabilities":{"alwaysMatch":{"browserName":"MiniBrowser"}}}'   # → sessionId
curl -X POST :9515/session/$SID/url -d '{"url":"https://web.stremio.com/"}' ; sleep 14
# 3. probe the exact core fetch from REAL content context (execute/async):
curl -X POST :9515/session/$SID/execute/async -d '{"script":"const d=arguments[arguments.length-1];(async()=>{try{const r=await fetch(\"http://127.0.0.1:11470/settings\");d(\"OK \"+r.status)}catch(e){d(\"FAIL \"+e.message)}})()","args":[]}'
```
Expected: http leg FAIL (Load failed), https leg (`https://127-0-0-1.<uuid>.stremio.rocks:12470/settings`) OK 200.
MiniBrowser opens a window on the user's Wayland session; kill driver+`pkill -f 'MiniBrowser --automation'` after.

## Engine swap commands (A/B official vs community)

Community engine = accru's supervised child; kill node pid on 11470 → launcher bash exits, lock freed.
Official: unpack `stremio-service_amd64.deb` (`ar x` + `tar -xf data.tar.xz`); run
`/usr/share/stremio-service/server.js` with system node:
`NO_CORS=1 FFMPEG_BIN=<ffmpeg> FFPROBE_BIN=<ffprobe> node server.js` (HOME same → reuses ~/.stremio-server cert/settings).
Restore community: `bash scripts/stremio-linux.sh --no-browser --data-dir=$XDG_DATA_HOME/stremio-accru` (single-instance flock free after old launcher exits).
Stremio-service URLs: https://dl.strem.io/stremio-service/vX/… ; GitHub release assets include `stremio-service_amd64.deb`; updater descriptor `https://www.strem.io/updater/check?product=stremio-service`.
