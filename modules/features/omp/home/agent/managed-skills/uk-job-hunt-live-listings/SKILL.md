---
name: uk-job-hunt-live-listings
description: "Find and verify live UK job listings (Nottingham/any city) when web_search providers are down: pull a client-rendered resume site's CV PDF, query Reed's __NEXT_DATA__ JSON and the LinkedIn public guest jobs API, verify each posting's real location and open status, and filter fee-charging trainee-scheme spam."
---

# Find and verify live UK job listings without web_search

Use when asked to "find N jobs in <UK city> I can apply for", especially when `web_search` fails (Startpage/DDG/Google all error with bot-challenges or timeouts). Ground every listing in a fetched, verified page — never invent postings.

## 1. Get the candidate's CV first

If the CV is on a personal site that looks client-rendered (SPA), the bare HTML only has meta tags. The real content is one of:

- A PDF linked from the JS bundle: `curl -s <site>/assets/index-*.js` then search for `/cv/*.pdf` or `.pdf` hrefs, and `read` the PDF URL directly (the read tool converts PDFs).
- Examples seen: `https://davr.is-a.dev/cv/junior-software-engineer.pdf`, `.../cv/it-technician.pdf`.
- Do NOT conclude "no resume content" from the HTML shell alone — check the bundle for PDF/text links.

## 2. Reed — structured JSON, no key

`GET https://www.reed.co.uk/jobs/<slug>-jobs-in-<city>` returns 200 (curl with a desktop UA). The jobs live in a Next.js blob:

```js
const d = JSON.parse(html.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/s)[1]);
const jobs = d.props.pageProps.searchResults.jobs; // each: { jobDetail:{...}, url:"/jobs/<slug>/<id>" }
```

Useful `jobDetail` fields: `jobId, jobTitle, ouName (employer), displayLocationName, salaryFrom/To, workingOption, dateCreated, taxonomyLevel2, jobDescriptionSnippet`. Dedupe by `jobId` across query slugs. Try slugs: `software-developer`, `junior-software-developer`, `graduate-software-engineer`, `junior-developer`, `it-technician`, `it-support-...`.

## 3. LinkedIn — public guest jobs API

`https://www.linkedin.com/jobs-guest/jobs/api/seeMoreJobPostings/search?keywords=<q>&location=<City>%2C%20England%2C%20United%20Kingdom&start=<0|25|50>`

Returns HTML fragments (200, no login). Extract ids with:
`/urn:li:jobPosting:(\d+)"[\s\S]*?base-card__full-link[^"]*" href="([^"?]+)/g`.
The inner title/company regexes are brittle — instead fetch each job page and read `<title>` (it encodes "Role at Company — City, Country | LinkedIn").

**Critical:** the location param is fuzzy — results include Birmingham/Derby/Leicester/remote. You MUST open each candidate and read its own `<title>`; keep only those matching the target city. Loop queries (software developer, junior/graduate variants, IT support/technician, helpdesk, full stack, devops, data engineer, python) × start 0/25/50.

## 4. Verify each shortlisted posting

Fetch `https://uk.linkedin.com/jobs/view/<id>` and check:

- Location and seniority — from `<title>` and `description__job-criteria-text` blocks (Entry/Mid-Senior/Full-time).
- Open status — `closed = /no longer accepting|job has been filled/i.test(html)`.
- Full JD — `show-more-less-html__markup` div; strip tags for responsibilities/skills/salary.
- Salary and "Remote" often appear in the JD body, not the card.

Direct ATS/employer apply URLs are usually hidden behind LinkedIn login — the LinkedIn job URL is a valid live application path; name the employer so the candidate can also apply on the employer's own careers page.

## 5. Filter the junk

UK "junior/trainee" feeds are dominated by fee-charging training schemes with no real employer: **ITOL Recruit, IT Career Switch, Newto Training, Qualify Nation, PROGRAD, Newto**. Red flags: "Trainee …", "job guarantee", "No experience needed", absurd salary bands (£10k–£100k/£100k+), same recruiter spamming dozens of near-identical titles. Exclude them and say so.

## 6. Report shape

A compact table: Role | Company | Location | Pay | Level | one-line why-fit mapped to the CV's actual stack/projects | live URL. Add 2–3 backups, and a "skip these" note for the scheme spam. State the verification date and that the sources were Reed structured search + LinkedIn guest API (since web_search was unavailable).

Other UK sources worth probing when needed: `totaljobs.com`, `jobsite.co.uk` (200 but client-rendered — no data in HTML), `cv-library.co.uk` and `adzuna.co.uk` (403 to curl), `findajob.dwp.gov.uk` (frequently 503). Indeed returns 403.

## Pitfalls

- Nushell/`nu` handles JSON, but this whole flow is plain regex over fetched HTML — do it in the `eval` (js) tool with `curl` via `child_process`, not bash pipelines.
- Batch the per-job fetches; ~110 LinkedIn pages took ~90s serially. Background long loops.
- Never present a posting whose location you have not read off its own page.
