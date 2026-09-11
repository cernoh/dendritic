---
name: web-data-source-reconnaissance
description: "Map whether a website's product, stock, or store data is reachable programmatically: the robots.txt-to-bundle probe ladder, per-store stock levels (quantity vs flag vs absent), verifying a delegated research report's endpoint claims before relying on them, credential handling, and the reporting template. Use when scoping a scraping or API integration for an e-commerce site, or when checking a web-data research report."
---

# Web data-source reconnaissance

Procedure for mapping whether a website's product, stock, or store data is
reachable programmatically, and for verifying the claims afterwards. Built while
scoping a UK retailer price/stock search (B&Q, Wickes, Screwfix, Toolstation),
2026-09.

Run the steps in order. Stop as soon as the question is answered. Each step is
cheaper than the next.

## The probe ladder

1. **`robots.txt` first, always.** It is one small GET and it sets the rules for
   everything after. Read it in full, not just the `Disallow` lines.

   Rules differ per path on the same site. A real example: Wickes `Disallow:
   /search` while permitting `/p/<SKU>` and `/store-pickup/*`. Record which of
   *your* needed paths are forbiddden, not a site-wide verdict.

   Also note `Crawl-delay`, and any `User-agent: <name>` group with `Disallow: /`
   (a bot block list). Never pick a User-Agent name from that list.

2. **The terms page.** Look for a clause naming scraping, crawling, automated
   access, data extraction, or republication. Report the clause as found.

   "None found" is a real and useful result — say that instead of a favourable
   reading. Toolstation had no such clause; Screwfix §4.2 forbids crawling
   outright. Same industry, opposite answer.

3. **One plain `curl` against the page you need.** Many sites server-render.
   Check before assuming JavaScript is required:

   ```bash
   curl -s -o page.html -w 'status=%{http_code} time=%{time_total} bytes=%{size_download}\n' URL
   ```

   Then count data markers in the HTML (`grep -o '£[0-9]' | wc -l`, or product
   `data-testid` values). Hundreds of hits means the data is already there.

4. **Look for an embedded state blob.** In priority order: `__NEXT_DATA__`,
   `__NUXT__`, `__PRELOADED_STATE__`, `__reactRouterContext`, then JSON-LD
   `<script type="application/ld+json">`. JSON-LD is often the cleanest route
   because it is designed for machine consumption.

5. **Read the bundle for the real XHR endpoints.** The network calls live in the
   shipped JavaScript. Pull the chunk named after the feature and search it:

   ```bash
   curl -s 'https://site/_next/static/chunks/<chunk>.js' -o chunk.js
   ```

   Search for `bff`, `graphql`, `stock`, `availability`, `api`, and the string
   `/v1/`. A hit in the bundle is a candidate endpoint, not proof.

6. **Probe candidate endpoints.** Send a status-only request first, then a real
   GET with a browser User-Agent. Expect 404 for a private app route, 401 or 403
   for a missing credential, 405 for a wrong method.

7. **Store locator.** One call that returns every store with latitude and
   longitude is worth far more than scraping store pages one at a time. Prefer
   it. Check whether coordinates are present or need a second pass.

## Per-store stock: what to look for

Stock is quantity-level, flag-level, or absent. Establish which.

- A quantity (an integer per store) is the strongest answer and the only one
  that supports "in stock now" plus a distance.
- An availability flag (`inStock`/`outOfStock`) is weaker but usable.
- A national "in stock" roll-up is not store-level and does not answer a
  distance-based question.

Also check the **pagination** behaviour early. It is easy to miss and it changes
the design: one retailer returned 2 stores per call with 228 total, and no
query parameter raised the page size.

## Verification (do not skip)

A delegated research report is a claim, not a fact. Re-run the one or two
load-bearing requests yourself before you file work on them.

This session's two outcomes, both from the same class of claim:

- A report claimed a cookie was required for a stock POST. A bare cookie-less
  `curl` returned 200 with the full stock JSON in 0.56 s. The requirement was
  not enforced, and the adapter got simpler.
- A report claimed per-store stock on a JSON:API endpoint with the exact field
  paths. Re-running it against four product IDs returned no `stock` key at all
  and no `included` array. The claim was not reproducible.

So: verify both the positive claims (which simplify a design) and the negative
ones (which block work). Report what you observed, with status codes.

## Handling credentials

A token embedded in page HTML is public-by-design, but:

- Read it at run time from a page. Never hardcode it, never commit it.
- Do not paste the value into an issue, a commit, or a doc. Record the header
  name and the field path instead.
- Expect rotation. A 401 saying the token expired means refresh and retry once.

Verify the ban before publishing:

```bash
git grep -I -c -- '<token-fragment>' HEAD
for i in $(seq 1 N); do gh issue view $i --json body --jq .body; done | grep -c '<token-fragment>'
```

## Reporting template

For each source, report these fields with evidence:

1. Permission: the `robots.txt` lines that touch your paths, and the terms clause.
2. Access: none, public key, session, or bot gate.
3. Endpoint: exact URL template, method, and required headers.
4. Response: the JSON path to each field you need.
5. Stock: quantity, flag, or not available at that granularity.
6. Pricing/cost and rate limits, with the recovery time if you hit a 429 or 503.
7. Verdict: permitted, tolerated, or blocked — plus adapter status.
8. Anything unobtainable marked `NOT ESTABLISHED` with what you tried.

## Pitfalls

- **A burst gets you throttled.** ~130 rapid requests to one host produced 503
  responses and a 90–120 s outage for that host. Serialise per host from the
  start.
- **A status code alone is not an answer.** Measure that the body carries the
  data, or you will file an issue built on a shell page.
- **Two hosts, same data.** A mobile API host and a public host often behave
  differently, including which `Accept` header they tolerate (`application/json`
  vs `application/vnd.api+json`).
- **Do not transfer one site's answer to another**, even within one corporate
  group. Same company, different robots.txt and different terms.
