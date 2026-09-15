---
name: career-ops-onboarding-scan-filters
description: "Personalize a career-ops checkout from a source CV and tune its portals.yml title/location filters. Covers the doctor unpersonalized signal, grounding proof points before writing them, location_filter precedence, the inert word: prefix in location entries, US city-name collisions, and why disabling a board does not clear data/pipeline.md."
---

Applies to a career-ops checkout (`github.com/career-ops-hq/career-ops`). Verified 2026-09-13 on a fresh clone at v1.32.0, driven headlessly by OMP.

## Layout facts that catch you out

- The **user layer** is gitignored: `cv.md`, `config/profile.yml`, `portals.yml`, `modes/_profile.md`, `modes/_brief.md`, `data/*`, `reports/*.md`, `output/*`, `jds/*`, `documents/*`. Confirm with `git check-ignore -v <path>` before telling anyone their data is safe.
- `doctor.mjs` **auto-copies** `modes/_profile.md` and `modes/_brief.md` from their templates, so those files always exist and the existence check can never catch them. The real signal is `unpersonalized[]` in `doctor.mjs --json`. Left unedited, every A–F evaluation scores against the **template author's** archetypes.
- `modes/_profile.md` feeds full evaluation; `modes/_brief.md` feeds triage. **Both** need replacing — fixing one only half-helpers.
- `config/profile.yml` and `portals.yml` are NOT auto-copied; they are the genuinely `missing[]` ones.

## Onboarding from a source CV

1. Read the CV. A remote PDF reads fine through the `read` tool directly on its URL.
2. **Ground every claim before writing it.** For a public GitHub handle, `gh api 'users/<user>/repos?per_page=100&sort=pushed'` yields languages, stars, created/pushed dates and fork status; `gh api repos/<u>/<r>/contributors` confirms authorship. The repo's no-fabrication rule is strict, and authorship claims are the most common violation. The portfolio usually contains proof points the CV omits — surface them rather than inventing new ones.
3. Write `cv.md` (canonical; restate the source, do not embellish), `config/profile.yml`, `modes/_profile.md`, `modes/_brief.md`.
4. Leave `location.visa_status` / `authorized_in` / `needs_sponsorship` **commented out** when unknown. A guessed value silently mis-scores every offer; an absent one makes the report say UNKNOWN, which is honest. Ask the user.
5. Benchmark `compensation` — do not carry over the template's senior USD figures. Search current market data for the candidate's actual level and market.

Verify: `node doctor.mjs --json` → `onboardingNeeded:false` **and** `unpersonalized:[]`. Then `node cv-sync-check.mjs`.

## portals.yml filters

`title_filter`: `positive` / `negative` / `seniority_boost`. This tier **does** support `word:` and `stem:` prefixes. `seniority_boost` adds relevance only — never a gate.

`location_filter` — `scan.mjs`'s `buildLocationFilter`, evaluated in order:

1. `block_hard` matches → reject
2. `always_allow` matches → pass
3. `block` matches → reject
4. `allow` empty → pass; otherwise `allow` must match

Traps, all measured rather than assumed:

- **An empty location always passes.** A provider that emits no location (some iCIMS tenants do) therefore leaks off-policy rows. Fix at the source by disabling that entry — no filter rule can catch a blank.
- **`block_hard` is a no-op unless `always_allow` is present.** It exists only so a country token cannot be resurrected by `always_allow`. Adding it to a config with no `always_allow` changes zero verdicts.
- **`word:` is NOT supported in `location_filter`.** `compileLocationKeyword` takes entries literally, so `word:MA` compiles to a search for the text `"word:ma"` and matches nothing — silently inert while looking correct.
- Location entries are auto-anchored `(?<![a-z0-9])…(?![a-z0-9])` when they start *and* end alphanumeric. So a bare `MA` matches the standalone word anywhere, including `or`, `in`, `me`, `hi`, `ok`, `de`, `la` inside free-text locations. Use the **comma form** `", MA"`; it is also the shape ATS feeds emit (`"Birmingham, AL"`).
- English city names have exact US duplicates: Birmingham (AL), Cambridge (MA), York (PA), Lincoln (NE), Reading (PA), Portsmouth (NH), Oxford (MS), Manchester (NH). A bare city in `allow` admits all of them. Add US state names plus comma codes to `block`.

Verify with the scanner's own filter — this is the step that catches an inert entry:

```bash
node -e '
const y=require("js-yaml"),fs=require("fs");
const cfg=y.load(fs.readFileSync("portals.yml","utf8"));
import("./scan.mjs").then(m=>{
  const f=m.buildLocationFilter(cfg.location_filter);
  let bad=0;
  for (const p of [["Birmingham, AL",false],["Nottingham, England",true],["Remote",true]]) {
    const ok=f(p[0])===p[1];
    if(!ok) bad++;
    console.log((ok?"ok   ":"FAIL ")+p[0]);
  }
  console.log("mismatches="+bad);
});'
```

Then `node validate-portals.mjs` (expect 0 errors) and `node verify-pipeline.mjs`.

## Nothing you disable leaves the inbox

Setting `enabled: false` on a `tracked_companies` entry stops future scans. It does **not** touch `data/pipeline.md`, so rows already written remain pending and will still be evaluated. Delete them from the pending list separately.

## Ask the audit before disabling a board

`node audit-portals.mjs --company <Name> --json` → `verdict: "no-provider"` means no provider claims the entry and it declares no `scan_method`, so `scan.mjs` skips it every run while `verify-pipeline` still counts it as coverage. Disabling then loses nothing. Do not disable on a warning alone — the audit runs the same provider modules `scan.mjs` uses, so it is the authority.

## Tracker writes

- Write one TSV to `batch/tracker-additions/{num}-{slug}.tsv` **with a header row**, then run `node merge-tracker.mjs`. Never hand-edit `data/applications.md`.
- Bootstrap `data/applications.md` with a header that **includes a `URL` column**, or merge's URL-first dedup has nothing to key on and columns shift on write.
- Reports need `**URL:**`, `**Legitimacy:**`, and a `## Job Description (archived verbatim)` section — `node check-jd-archive.mjs` enforces the last one.

## Do not run the updater over local system edits

`node update-system.mjs apply` raw-`git checkout`s every `SYSTEM_PATHS` file from upstream and prunes paths upstream no longer ships. With local edits to system files (a new CLI wrapper, a dev-shell change), `apply` reverts them and can delete a file it does not know about. `check` reporting `system-files-changed` is expected while that work is unlanded.

## Cost shape

`node scan.mjs` is zero-token; `--verify` adds Playwright liveness checks; `--dry-run` previews without writing. The evaluation modes (`pipeline`, `auto-pipeline`) are what spend model tokens, so filter accuracy is what protects the budget.

## Headless driving

Registering a CLI host (context files, skill discovery, headless invocation) is covered by the `omp-project-context-shadowing` skill. Once registered, evaluation runs cleanly as `omp -p "<mode + URL>"` and reports back the score, report path and hard blockers.
