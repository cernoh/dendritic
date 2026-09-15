---
name: career-ops-local-parser-boards
description: "Integrate a careers board that no bundled career-ops provider can read, as a zero-token local_parser shelling to browser-extract.mjs: the dead-end ladder to walk first (client-rendered listing, WordPress AJAX nonce wall, unsupported ATS like BrassRing/inploi), where parser scripts must live, the jobs-json-v1 stdout contract, nav-junk filtering, and how to verify through scan.mjs. Use when discover-ats.mjs reports a company unresolved, when audit-portals.mjs returns no-provider/error for a board you need, or before giving up and settling for a websearch entry."
---

# Reading a careers board no provider supports

`discover-ats.mjs` resolving nothing does not mean the board is unreadable. It
means no *bundled provider* claims it. A `local_parser` that drives the repo's
own Playwright helper is the supported escape hatch, and it stays zero-token —
only the normalised rows reach the pipeline.

Verified 2026-09-13 on Boots (`boots.jobs`), which resolved nothing and is now a
working board.

## Walk the ladder before concluding "unsupported"

Cheap checks first. Each rung fails loudly, which is what makes the next one
justified.

1. **Plain HTTP.** `curl -sSL -A "<browser UA>" <listing-url>`. If the HTML
   carries real job links, a trivial parser or a provider may already work.
   Boots: 151 KB of HTML, **0** job links — client-rendered.
2. **Find the data endpoint.** Grep the page for `admin-ajax.php`, `wp-json`,
   `/api/`, `ajaxurl`, `rest_url`. Boots exposed a WordPress action config:
   `boots_job_search_filtered` on `/wp-admin/admin-ajax.php`.
3. **Try the endpoint.** POST with `action=` and the page's own query params.
   Boots returned real JSON — and `{"success":false,"data":{"message":"Invalid
   request nonce."}}` at HTTP 403. The nonce is not issued to logged-out
   callers. A nonce wall is terminal; do not hunt for a bypass.
4. **Fingerprint the ATS.** Fetch the careers page and match vendor strings
   (`myworkdayjobs`, `icims.com`, `successfactors`, `avature`, `taleo`,
   `brassring`, `inploi`, `phenom`, `teamtailor`, …). Boots: WordPress front-end
   → **inploi** feed → **BrassRing** (`krb-sjobs.brassring.com`). The repo
   supports neither.
5. **Try Playwright.** `node browser-extract.mjs "<url>" --mode listing`. If it
   returns JSON with job links, stop — write the parser.

Only after rung 5 fails is a `websearch` entry the honest answer.

## Where the script lives

Put it in **`local/`**, e.g. `local/parsers/<company>-jobs.mjs`. That directory
is gitignored (`.gitignore` line 4) and is the documented user-owned location
per `docs/local-parser-cookbook.md`. A file in `scripts/` or the repo root is a
system-path concern: `update-system.mjs` owns those and will overwrite or prune
it on the next update.

## Parser contract

`scan.mjs` runs `parser.command` with `parser.script` and expands
`{careers_url}` / `{company}` in `parser.args`. No shell interpolation. Print
one of these shapes to stdout:

```json
[{ "title": "...", "url": "...", "location": "..." }]
{"jobs":    [...]}
{"results": [...]}
```

`title` and `url` are required; `location` is optional but worth supplying —
`scan.mjs` persists it and the location filter reads it. Relative URLs resolve
against `careers_url`.

### Call the helper, do not re-implement scraping

```js
import { execFileSync } from 'node:child_process';
const raw = execFileSync(
  process.execPath,
  [join(REPO, 'browser-extract.mjs'), target, '--mode', 'listing'],
  { encoding: 'utf-8', timeout: 120_000, stdio: ['ignore', 'pipe', 'pipe'] },
);
```

Resolve `REPO` from `import.meta.url`, not `process.cwd()` — `scan.mjs` may run
the parser from anywhere.

## Two traps

**Nav junk.** `--mode listing` returns every anchor, not just postings: Boots
returned "Support Office", "Nottingham, Nottingham Support Office" and
radius-filter links alongside real roles. Filter in the parser, before `scan.mjs`
sees the output. Real postings are the only URLs shaped `/jobs/<reqid>-<slug>`:

```js
const JOB_URL = /\/jobs\/[0-9a-z]+-/i;
```

**Exit codes.** On a scrape or JSON failure, print a message to stderr and
`process.exit(1)`. `scan.mjs` then records the failure and falls through to any
detectable API source. Exiting 0 with junk silently poisons the run. But zero
real postings is a *legitimate* result — emit `{"jobs":[]}` and exit 0, or
`scan.mjs` records a spurious error for a genuinely empty board.

## portals.yml entry

```yaml
- name: Boots
  careers_url: https://www.boots.jobs/search-jobs/?submit=1&jobfeed=external
  scan_method: local_parser
  parser:
    command: node
    script: local/parsers/boots-jobs.mjs
    format: jobs-json-v1
    args:
      - "https://www.boots.jobs/search-jobs/?submit=1&jobfeed=external&function_area=Technology"
  notes: "..."
  enabled: true
```

Point `args` at the **narrowest listing** that covers your target roles — a
per-department URL costs one page instead of the whole board.

## Verification

```bash
node validate-portals.mjs                       # 0 errors required
node scan.mjs --company <Name> --since 120      # shows the parser path
node verify-pipeline.mjs                        # 0 errors
```

The scan summary proves the chain, not just the script:

```
Scanning 1 companies; 1 local parser; 0 skipped — no provider matched
Total jobs found:      11
Filtered by title:     11 removed
```

`1 local parser` and `0 skipped` mean `scan.mjs` claimed the entry.

**A 0-new-offers result can be correct.** Boots' entire tech board is
senior-level, so the graduate `title_filter` rejected all 11 — that is the
filter working, not a broken parser. Confirm by checking a few of the 11 titles
against your `negative` list before "fixing" anything.

## Related

- `career-ops-ats-board-discovery` — finding a board in the first place, and the
  no-provider/Vinted failure class. This skill is the rung that follows it.
- `career-ops-onboarding-scan-filters` — `title_filter` / `location_filter`
  tuning, including the inert `word:` prefix in location entries.
- `docs/local-parser-cookbook.md` — upstream contract for parsers.
