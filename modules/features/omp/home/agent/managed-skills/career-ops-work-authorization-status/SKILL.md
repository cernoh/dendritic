---
name: career-ops-work-authorization-status
description: "Record a candidate's work-authorization status in a career-ops checkout so evaluations score it correctly: the authorized_in/needs_sponsorship split, why needs_sponsorship governs only roles OUTSIDE authorized_in, the trap that setting it false mis-scores non-UK roles while doing nothing for the UK, where to verify immigration status from primary sources, and why the visa_status string itself is quoted verbatim while the comment above it is not."
---

# Recording work authorization in career-ops

Verified 2026-09-13 against career-ops v1.32.0 while onboarding a UK candidate on a
10-year settlement route.

## The two keys, and the interaction that is easy to get wrong

`config/profile.yml` → `location`:

```yaml
location:
  visa_status: " ... free text, read by the evaluator ... "
  authorized_in: ["United Kingdom"]   # where the candidate ALREADY holds work rights
  needs_sponsorship: true             # applies ONLY to roles OUTSIDE authorized_in
```

`modes/oferta.md` Block A ("Work-authorization check") defines four tiers:

| Tier | Condition | Scoring effect |
| --- | --- | --- |
| ✅ Sponsors | JD offers sponsorship/relocation AND role outside `authorized_in` | neutral |
| ➖ Not needed | role in `authorized_in` **OR** `needs_sponsorship` is false | neutral |
| ⚠️ Unstated | role outside `authorized_in`, JD silent | **neutral** — silence is not refusal |
| ⛔ No sponsorship | JD explicitly refuses **AND** role outside `authorized_in` | hard stop |

**The critical consequence:** if the candidate's country is in `authorized_in`, a
`⛔` is *unreachable* for that country — the tier requires the role to be outside
`authorized_in`. So a JD saying "we do not sponsor" is **irrelevant, not
disqualifying**, for any role in a country they are already authorized in.

**Therefore do NOT set `needs_sponsorship: false` to "help" domestic
applications.** It changes nothing for them (they already clear on
`authorized_in` alone) and it actively mis-scores foreign ones: a US role stating
"no visa sponsorship" would drop from ⛔ hard-stop to ➖ Not needed. `true` is
correct whenever the candidate lacks rights abroad.

Write this reasoning into the YAML comment. It looks like an easy "fix" to a
later reader and will otherwise be flipped.

## Put operative facts in the value string, not only the comment

`visa_status` free text is what a report or form-filler quotes verbatim; the
comment above it is not read by the evaluation. A renewal date, a condition of
grant, or a "no sponsorship required" statement belongs in the string. Keep the
long rationale in the comment.

## Verify the status from primary sources, not summary pages

The GOV.UK landing page describes a route's *purpose and fees* but often not the
**conditions of grant**. The work-rights condition lives in the Immigration
Rules appendices. For UK statuses, fetch the appendix itself, e.g.:

```
https://www.gov.uk/guidance/immigration-rules/immigration-rules-appendix-long-residence
https://www.gov.uk/guidance/immigration-rules/immigration-rules-appendix-private-life
```

Then grep for `work (including self-employment|work is permitted|no access to public funds|period of grant`.
Long Residence LR 8.1(b) and Private Life PL 10.5 read "work (including
self-employment and voluntary work) permitted".

**Colloquial route names collide.** "10-year route" is used for at least two
distinct routes (Appendix Long Residence; the private-life/family route). If the
user's phrasing is ambiguous, check both and write the entry to cover both rather
than attributing them to one appendix — and say in the comment that the specific
route was not disambiguated. Do not invent a citation to fill the gap.

## Feeding the rest of the system

Keep these three in sync; the first is what scoring reads, the other two are what
the agent reads:

- `config/profile.yml` → `location.visa_status` / `authorized_in` / `needs_sponsorship`
- `modes/_profile.md` → "Work Authorization": the screening-question answers and the explicit "how to score it" instruction
- `modes/_brief.md` → Identity: one compact line, because triage reads this per role

When correcting a status, **rewrite** the existing section rather than appending —
an older "status not yet confirmed" paragraph left in place contradicts the new
one and the agent reads whichever it lands on.

## Verification

```bash
node doctor.mjs --json          # onboardingNeeded false, no unpersonalized entries
node cv-sync-check.mjs          # All checks passed
node -e "const y=require('js-yaml'),f=require('fs');
  const p=y.load(f.readFileSync('config/profile.yml','utf8'));
  console.log(p.location.visa_status, p.location.authorized_in, p.location.needs_sponsorship)"
```

That inline parse matters after editing: `visa_status` is usually a `>-` block
scalar, and a badly indented comment inserted above it silently breaks the fold.
Confirm the whole string parses and still ends where you expect.

## Confirming the correction reached a live evaluation

Run one evaluation and read its Block A line. For a UK-authorized candidate on a
UK role it must read **➖ Not needed**. A `⚠️` or `⛔` there means the config was
not picked up. This is cheap empirical proof that the edit landed — prefer it
over re-reading the YAML.

## Related

- `career-ops-onboarding-scan-filters` — the portals.yml title/location side
- `modes/oferta.md` Block A is the authority; read it rather than trusting this
  summary if the version has moved
