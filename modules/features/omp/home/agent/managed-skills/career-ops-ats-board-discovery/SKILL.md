---
name: career-ops-ats-board-discovery
description: "Find and validate a careers board URL before adding an employer to career-ops portals.yml: discover-ats.mjs gaps (iCIMS, Teamtailor-on-branded-host, Workday with a non-tenant board segment), fingerprinting the careers page for ATS vendors, the Workday segment trap, and the no-provider/Vinted failure class. Use when adding companies to portals.yml, when discover-ats reports \"board found but 0 jobs\", or when an entry audits as no-provider or error."
---

Verified 2026-09-13 against career-ops v1.32.0 by adding 11 Nottingham/East Midlands employers. Complements `career-ops-onboarding-scan-filters`, which owns filter semantics; this skill owns *finding and validating the board URL*.

## The rule that matters

Never add an entry whose board no provider claims. That is the **Vinted failure class**: `scan.mjs` skips it every run while it still counts as configured coverage, so `verify-pipeline` reports healthy coverage it does not have. Validate every new entry with `audit-portals.mjs` before trusting it, and prefer a commented note over an entry when nothing claims the board.

## Workflow

1. Write a candidate list, then resolve slugs in bulk:
   ```bash
   node discover-ats.mjs --in /tmp/companies.yml --summary     # preview, writes nothing
   node discover-ats.mjs --in /tmp/companies.yml --write       # appends to portals.yml
   ```
   `--write` appends. If you also hand-write entries for the same companies you get duplicate-name warnings from `validate-portals.mjs` — pick one route.

2. For every company it reports as **"board(s) found but currently list 0 jobs"**, treat that as *unresolved*, not as an empty board. It usually means the probe matched a landing page rather than the real board.

3. Fingerprint unresolved employers by fetching their careers page and matching vendor markers. This is where the real finds are:
   ```bash
   curl -sSL --max-time 25 -A "Mozilla/5.0" "<careers-url>" \
     | grep -oE 'https?://[a-z0-9.-]*(myworkdayjobs|icims|teamtailor|successfactors|avature|phenom)[a-zA-Z0-9/_.-]*' | sort -u
   ```
   Then pull the exact board path out of the **employer's own careers page**, not from a guess (see the Workday trap below).

4. Verify each entry:
   ```bash
   node validate-portals.mjs
   node audit-portals.mjs --company "<Name>" --json
   ```
   Verdicts: `ok` / `small` / `empty` (live) are fine. `no-provider` or `error` must be fixed or turned `enabled: false` in the same pass. `--company` is the fast per-entry check; the full audit costs a fetch per board.

## Gap 1 — discover-ats misses real boards

Excluding a vendor from `--vendors` (or omitting it) silently narrows the probe. Two live boards it reported as dead, both of which it can in fact read once you supply the URL:

- **iCIMS** — `discover-ats`'s BambooHR probe redirected and reported 0 jobs; the company actually ran `careers-<tenant>.icims.com`. iCIMS auto-detects from any `*.icims.com` host, so an explicit entry works.
  ```yaml
  - name: Example Co
    careers_url: https://careers-exampleco.icims.com/jobs/search?ss=1
    enabled: true
  ```

- **Teamtailor on a branded host** — a branded careers domain carries no `teamtailor` string, so auto-detection cannot match. Set the provider explicitly; it reads the same public `/jobs.rss`:
  ```yaml
  - name: Example Co
    careers_url: https://careers.exampleco.co.uk
    provider: teamtailor
    enabled: true
  ```

Same shape applies to SuccessFactors RMK on a branded host (`provider: successfactors` + `api: <board origin>`) and to Workday.

## Gap 2 — the Workday segment trap

The board path segment is **not** always the tenant name. Guessing it returns HTTP 404 and audits as `error`:

```yaml
# WRONG — 404:
careers_url: https://acme.wd3.myworkdayjobs.com/acme
# RIGHT — taken from the employer's own careers page:
careers_url: https://acme.wd3.myworkdayjobs.com/careers
```

Find the real segment by grepping the careers page for `myworkdayjobs.com` links, rather than inferring it from the tenant.

## Unresolvable employers

Large UK employers (retail, energy, aerospace, universities) often run custom career sites with no vendor fingerprint at all. Nothing can read them. Record them as a **comment block**, never as entries:

```yaml
# ── Employers with NO machine-readable board ──
#   Acme Retail     acme.jobs          no provider fingerprint found
#   Acme University jobs.acme.ac.uk    homegrown, no ATS
```

A `scan_method: websearch` entry with a verified `scan_query` is the honest fallback when you want them covered; it costs tokens per scan.

## Verification recipe

```bash
node validate-portals.mjs                                  # 0 errors, 0 warnings
node audit-portals.mjs --company "<Name>" --json           # per-entry verdict + count
node scan.mjs --since 30 --quiet                           # prove it survives title+location filters
node verify-pipeline.mjs                                   # no no-provider coverage
```

`audit-portals.mjs` runs the same provider modules `scan.mjs` uses, so its verdict — not a fetch of the careers page — is the evidence that a board is readable.
