---
name: search-when-engines-are-blocked
description: "Find web results when the harness web_search tool fails and DuckDuckGo, Bing, Mojeek, Brave, Ecosia and Startpage serve captchas, 403s or canned SERPs: fetch Yahoo's SERP HTML through the scrapling MCP tools with css_selector \"#web\". Use when a research task returns nothing and the usual fallbacks are blocked."
---

# Search when every search route looks blocked

Symptom: `web_search` fails on every provider, and each engine you try returns a captcha,
a 403, or — worse — a *plausible* page with no results.

## Reach for this first

Fetch the Yahoo results page through the scrapling MCP `bulk_get` tool:

```json
{ "urls": ["https://search.yahoo.com/search?p=<url+encoded+query>"],
  "extraction_type": "text",
  "css_selector": "#web",
  "main_content_only": false,
  "timeout": 25 }
```

Yahoo renders organic results server-side, so plain HTTP works. It also honours
`site:` — `site:linkedin.com/in <company> <role>` returns real profile URLs with headline
and location text. Batch several queries per call.

Brave (`https://search.brave.com/search?q=`) also works but rate-limits after ~2 requests.

## How the others fail (observed 2026-09)

| Route | Failure |
|---|---|
| DuckDuckGo html + lite | bot challenge ("select all squares containing a duck") |
| Bing | HTTP 200 but a **canned** SERP: identical results for every query, terms ignored. Silent, so it is the dangerous one |
| Mojeek / Yep | ALTCHA challenge / 403 |
| Ecosia | 403 challenge |
| Startpage | "Verifying your request" (works once through a stealth browser, then suspends) |
| searx instances | Anubis proof-of-work or JS-only shell |
| `linkedin.com/in/<slug>` direct | HTTP 999 / `/authwall` — profile bodies are unreadable for guests |

## Rules that keep the output honest

- **Never construct a LinkedIn slug from a name.** They carry numeric suffixes. Copy the URL
  from the SERP snippet, or omit the person. A guessed profile is worse than a gap.
- **Label the evidence class.** Keep the SERP title/snippet that named the person, and say
  plainly that the profile page itself was not read.
- **Distrust employer metadata.** Yahoo's "Works For" field can show a *prior* employer and
  contradict the headline; flag the conflict rather than picking a winner.
- Prefer primary sources when they exist: a company's own careers or `management-team` page
  often carries LinkedIn `href`s verbatim — the strongest evidence available here.
- A bad URL aborts the whole batch ("Could not resolve host"). Use only real hosts.

## Verify before reporting

Return only people whose name, title and URL appeared together in fetched content. Report a
short verified list plus an explicit note of what could not be verified — a padded list is a
failure, not a result.
