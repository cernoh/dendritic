---
name: wfinfo-dashboard
description: "Work on the Warframe Info GOV.UK dashboard in the WFinfo-ext repo: run/gate commands, env vars, and the quirks of the WFInfo app-data files it reads (debug.log timestamps/reward lines, market_items/market_data join shapes, ocr_runs layout). Use when editing dashboard/ or adding pages/data sources to it."
---

# Warframe Info dashboard (dashboard/ in WFinfo-ext)

Deno + GOV.UK Frontend server over WFInfo's local app data. Pages: `/logs` (debug.log tail), `/recent` (reward screens from debug.log + OCR suite runs), `/wfmarket` (cached prices; per-slug detail with live warframe.market v1 90-day stats). Brand = "Warframe Info, independent digital service" (header logo asset, never GOV.UK crown).

## Run & gates
- Run: `nix develop` at repo root, then `cd dashboard && deno task dev` (PORT env to change port; default 8000 often busy — port 8765 known-free locally). App form: `nix run .#dashboard`.
- Gates: `deno fmt --check && deno check src && deno test -A src && deno lint`, plus `nix flake check` (sandboxed, must stay offline: dashboard/src imports NOTHING remote/npm; tests use local `lib/testutil.ts`).
- `deno.json` excludes AGENTS.md/README.md from fmt/lint and `src/static` from lint (browser JS: `var`, `window` are intentional there).
- Static page script `src/static/dashboard.js` polls `/api/logs`, `/api/reward-events`, `/api/ocr-runs` and re-renders; keep empty-state divs (`#wf-rewards-empty`, `#wf-runs-empty`) toggled by the same JS.

## App-data dir resolution (mirror headless Program.cs)
App dir = `$APPDATA/WFInfo` if APPDATA set, else `$WFINFO_DATA_DIR/WFInfo`, else `$XDG_CONFIG_HOME|~/.config` + `/WFInfo`. On this Linux box: `/home/davr/.config/WFInfo`. Dashboard only reads; never writes.

## Data-file quirks (learned the hard way)
- `debug.log` timestamps are .NET G-format under the machine culture: en-GB `[07/09/2026 21:09:12]` (24h) or en-US `[9/7/2026 9:09:12 PM]`. Day/month ambiguous when both <= 12: resolve toward the file's mtime anchor (fsdata.parseLogTimestamp).
- Reward screens appear as `A || B || C, detected choice: N` AddLog lines; only logged when auto-processing (AutoList/AutoCSV/AutoCount) fires on a session end.
- `market_items.json` values are 3 pipe fields: `Display|url_name|Full Name With Blueprint` (`split("|")[1]` is the wfm slug). Prime sets are filtered out; parts only.
- `market_data.json` (price sheet) carries TWO rows for blueprint parts: keyed `"X Prime Systems Blueprint"` (ducats 0) and `"X Prime Systems"` whose `name` field equals the blueprint name (real ducats). Lookups must prefer the row with ducats > 0 (indexMarket/lookupPrice in lib/items.ts).
- OCR suite results are PascalCase JSON (`TestSuiteName`, `TestResults`, ...); parser accepts camelCase too.
- Headless `--test` persists results to `<app dir>/ocr_runs/` (`latest.json` + timestamped; newest 60 kept). Runs are deduped by `suite|startedMs`.
- Dir-existence checks need `statSync().isDirectory`, not `isFile` (main.ts has both fileExists and dirExists).

## Live wfm stats
`lib/wfm.ts` hits `https://api.warframe.market/v1/items/{slug}/statistics` (public; no auth), reads `payload.statistics_closed["90days"]`, 10-minute in-process cache, graceful `ok:false`. Deno fetch header VALUES must be pure ASCII — an em dash in the User-Agent threw "not a valid ByteString".

## Verification without a browser
No runnable Chromium on this host (omp browser daemon fails; nix store holds sandbox stubs only). Visual checks are unavailable — verify with HTTP + a throwaway DOM assertion script: fetch each page, assert ids/classes/row counts/`<svg class="wf-chart">`, assets (`/govuk/govuk-frontend.min.css` > 50KB proves the unpkg mirror worked), then delete the script.
