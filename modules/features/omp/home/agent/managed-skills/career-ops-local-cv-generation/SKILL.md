---
name: career-ops-local-cv-generation
description: "Generate tailored, ATS-checked CV PDFs inside a local career-ops checkout: nix dev shell for node, personalize the gitignored user layer, archive JDs, run jd-skill-gap, then build-cv-html + verify-cv-facts + generate-pdf."
---

# career-ops local CV generation

Repeatable flow for turning job postings into tailored PDF CVs in a career-ops
checkout. Use when the user says "tailor CVs for these jobs" or runs the pdf mode.

## 0. Run node via the flake (node is NOT on PATH)

The repo is a Nix project; `node`/`nix-shell` may be missing from PATH. `nix` is
usually present. Run every node command inside the dev shell:

```bash
cd <repo> && nix develop --command bash -c '<node commands>'
```

The flake supplies node, bun, and pinned playwright browsers
(`PLAYWRIGHT_BROWSERS_PATH`). The shellHook runs `npm install --no-save playwright@<ver>`
on first entry — expect a one-time ~40s cache fetch. Also run
`npm install --ignore-scripts` once if `node_modules/` is absent (js-yaml etc.
are needed by `cv-templates.mjs`).

## 1. Personalize the user layer (first time only)

A fresh checkout has **no** user layer. `cv.md` and `config/profile.yml` are
**gitignored** — safe to write, no commit/PR needed; this is product use, not
repo development.

- `cv.md` — source of truth. Standard headers: Professional Summary, Core
  Competencies, Work Experience, Projects, Education, Skills. Only facts from
  the user's real resume (never invent skills/metrics).
- `config/profile.yml` — `candidate` (name, email, linkedin, github,
  portfolio_url, location), `target_roles`, `location`, `language.output`,
  `cv.output_format: html`. Surface `visa_status` to the user for confirmation
  rather than inventing work authorization.

Pull resume facts from the user's own site if pointed there. Client-rendered
SPAs return only meta tags over HTTP; the CV is usually linked as a **PDF**
(e.g. `/cv/<variant>.pdf`), which reads directly — grep the JS bundle for
`href:"/cv/..."` if unsure.

## 2. Archive each JD

Write `jds/<slug>.md` with a `**URL:**` header plus the full JD text. This file
IS the JD archive when pdf runs standalone.

## 3. Skill-gap check (per JD)

```bash
node jd-skill-gap.mjs jds/<slug>.md --summary
```

Classifies JD requirements against `cv.md` as `existing` / `supportedByResume` /
`gap`. **A `no-requirements-section` LOW CONFIDENCE result means the check did
not run** — read the JD yourself and report the gaps by hand. Never surface a
`gap` item as if the candidate has it; tell the user the gaps before generating.

## 4. Build payloads and render

Resolve the template, then per role:

```bash
TPL=$(node cv-templates.mjs resolve cv | tail -1)
node build-cv-html.mjs /tmp/cv-<candidate>-<company>.json output/cv-<candidate>-<company>.html "$TPL"
node verify-cv-facts.mjs output/cv-<candidate>-<company>.html
node generate-pdf.mjs output/cv-<candidate>-<company>.html output/cv-<candidate>-<company>-<YYYY-MM-DD>.pdf \
  --format=a4 --allow-reorder
```

Payload is compact JSON (never full HTML): `candidate`, `summary`,
`competencies[]`, `experience[]`, `projects[]`, `education[]`, `skills[]`.
UK/rest-of-world → `a4`; US/Canada → `letter`.

- `verify-cv-facts.mjs` is a **hard gate** — fix invented claims, do not skip.
- `--allow-reorder` avoids the section-order guard failing when `cv.md` has
  sections the template orders differently (e.g. Extra curricular, Competencies).
- Optional `node verify-ats.mjs <html>` gives an advisory 0-100 score
  (threshold 70).

## Verification

Report per CV: PDF path, page count, fact-gate result, ATS score, and any
remaining gaps. All the above must actually run — do not claim a PDF exists
without the `generate-pdf.mjs` output line.
