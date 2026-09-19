---
name: wayfinder-ticket-evidence-grounding
description: "Ground a wayfinder HITL ticket in repo evidence before asking the grill_form round: ticket dependency/frontier checks, dead-code and call-site verification, measure the migration surface by family, and write recommendations that cite file:line."
---

# Ground a wayfinder ticket before the grill round

Wayfinder resumes with "user gave a map or ticket URL". A HITL (grilling) ticket must not
open its `grill_form` round from the ticket text alone: the recommendations carry the round,
and unmeasured recommendations collapse the round into a rubber stamp. Measure first.

## 1. Orient in the tracker (before any repo work)

- Map: `gh issue view <n> --json number,title,body,labels,state,assignees,url`. The map body
  holds the Destination, the measured-surface Notes, and the gating tickets.
- Children, with live gates, in one call:
  `gh api repos/{owner}/{repo}/issues/<map>/sub_issues --jq '.[] | {number, title, state, assignees: [.assignees[].login], blocked: .issue_dependencies_summary}'`
- Per-ticket blockers when the summary is not enough:
  `gh api repos/{owner}/{repo}/issues/<n>/dependencies/blocked_by --jq '[.[].number]|join(",")'`
  — `blocked_by` counts only OPEN blockers, so it is the live gate.
- Frontier: `~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>` after claiming, to
  confirm the ticket is taken and no sibling session holds it.
- Claim first, then work: `gh issue edit <n> --add-assignee @me`.
- Read the gating tickets' full bodies. They usually contain decisions already settled
  ("Already decided: ...") that constrain the plan more than the ticket text does. A plan
  ticket's tiers must be *named by which open ticket gates them*.

## 2. Measure the surface the ticket is about

Answer these with commands, not impressions:

- **Dead code claim in the ticket?** Confirm it transitively:
  `git grep -n 'SymbolName' -- app/src/main | grep -v <defining file>` — a "dead" file
  referenced only by another dead file is transitively dead; say so explicitly, it changes
  the deletion list.
- **Unreferenced resources?** `git grep -n 'R\.anim\|R\.raw' -- app/src/main` returning
  nothing (exit 1) is the proof, not an eyeball of the resource directory.
- **Wrapper or component call sites?** Enumerate them and split production from `@Preview`:
  the preview-only ones do not belong in the migration tier. `git grep -n '<Wrapper>' -- app/src/main`.
- **Conditional forks that exist only to serve the old path?** Grep the wrapper's file for
  `Build.VERSION`, feature flags, or `if (!useDialog)` — a fork like `SDK_INT < 30` is why
  the old code survived, and the plan must retire it, not port it.
- **Defaults that make a "theme" load-bearing?** Grep the preference layer for the flag's
  default: `kv.decodeBool(KEY, true)` means the thing being deleted is the default look, so
  a deletion tier changes every screen, not a minority path.
- **Size each migration family** so tiers are session-sized:
  `for d in <families>; do printf '%-24s ' "$d"; git ls-files "<path>/$d/**/*.kt" | sort -u | xargs wc -l 2>/dev/null | tail -1; done`
- **Leverage points:** find the shared file a batch change rides on (`git grep -l 'PreferenceItem('`
  — one file's edit reaching dozens of screens is a mechanical tier; per-file work is not).

## 3. Write the round

- One decision per question; my recommendation first in the body, plus 2-4 short `choices`.
- Cite `file:line` for every claim the round rests on. The human is deciding against
  evidence, and a later session re-reads this round as the ticket record.
- Keep a glossary in the record for the names the plan invents (tier, gate, exit condition,
  ledger): the resolution comment is the durable copy, so invented vocabulary must be
  defined where it is first used.
- Write the round and a pending `## Settled decisions` list to `/tmp/wayfinder-<slug>.md`
  before calling `grill_form`, then end the turn with the returned URL only.

## Traps

- The bash tool blocks `find`, `cat`, `head` and shell `grep`/`rg`: use the `glob`, `read`
  and `grep` tools for paths and pattern searches; keep bash for one-call counts
  (`git ls-files | xargs wc -l | tail -1`, `git grep -l ... | wc -l`).
- Do not resolve the ticket in the same turn as the round: the submit injects the answers as
  the next user message, and the round is only settled once those answers land.
- A captured "automated capture turn" is not an answer: never continue the grill from it.
