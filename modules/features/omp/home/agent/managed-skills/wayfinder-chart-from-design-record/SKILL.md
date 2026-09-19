---
name: wayfinder-chart-from-design-record
description: "Chart a new wayfinder map on a GitHub repo from a completed grilling/design record: two-round grill_form cut, label setup, map-then-tickets-then-edges script, frontier verification with the 8s dependency lag, and the research-ticket agent brief"
---

# Charting a wayfinder map from a finished design record

Companion to `skill://wayfinder` chart mode. Use when a grilling session already produced a
design record and the user wants the map and its tickets created on GitHub. Verified on
`cernoh/jjsync` (2026-09-17): map #1, nine tickets, four edges, frontier correct.

## Check what already exists first

The repo, the DOX `AGENTS.md`, the licence and the gitignored design folder are usually
done by the preceding session (`skill://dox-repo-with-gitignored-design-folder`). Verify,
do not re-create: `gh repo view <owner>/<repo> --json visibility,defaultBranchRef` and
`gh api repos/<owner>/<repo>/issues --jq 'length'`. If the repo exists, say so and move on
to charting.

Read the design record *before* anything: it holds the destination, the settled decisions
(do not re-ticket them) and the fog. A `.design/README.md` often names the wayfinder entry
points outright — destination, decisions so far, fog, out of scope.

## Grill: two rounds, then finish

Round 1 (destination + frontier):
1. Destination — offer the record's own scope section as the recommendation; wayfinder
   plans, so phrase it "route cleared for building".
2. Which fog patches become tickets now — offer the record's risk list plus its milestone
   plan as labelled candidates (A–J), ask for a subset, and let the rest stay in
   **Not yet specified**.
3. Planning-only, or may task tickets build throwaway proofs? Get this answered explicitly:
   it becomes the map's Notes override.

Round 2 (ticket shape) only if a real cut remains: splitting a ticket whose two halves have
different blockers, and whether a prerequisite like a test remote gets its own ticket.

Then `grill_finish`. Never exceed two charting rounds — the design record already did the
heavy grilling; extra rounds are re-litigating settled decisions.

## Labels, then map, then tickets, then edges

Labels are one-time per repo (run before the map):

```bash
gh label create wayfinder:map       --description "Wayfinder canonical map"    --color 5319e7
gh label create wayfinder:grilling  --description "Wayfinder grilling ticket"  --color fbca04
gh label create wayfinder:prototype --description "Wayfinder prototype ticket" --color 1d76db
gh label create wayfinder:research  --description "Wayfinder research ticket"  --color 0e8a16
gh label create wayfinder:task      --description "Wayfinder task ticket"      --color d93f0b
```

`gh label list --search wayfinder` can lag a few seconds and hide the newest label — confirm
a suspicious absence with `gh label list --search <name>` before creating it again.

Write every body to a file first (`/tmp/wf-<topic>/map.md`, `01-<slug>.md`, …), then run one
script that does all of it in order, capturing numbers as it goes:

1. `gh issue create --title "<destination as a name>" --label wayfinder:map --body-file map.md`;
   take the number from the printed URL (`${url##*/}`) — `gh issue create` has no `--json`.
2. Create tickets in **route order** (that order is the frontier order), one per
   `--label wayfinder:<type>`, appending `key<TAB>number` to `ids.tsv`.
3. Second pass, sub-issues: `gh api --method POST repos/<o>/<r>/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`,
   the DB id from `gh api repos/<o>/<r>/issues/<n> --jq .id`.
4. Second pass, edges: `gh api --method POST repos/<o>/<r>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`.

Write the blocking edges only where a real prerequisite exists (toolchain before
cross-compile, cross-compile before the device proof). A ticket whose blocker is still fog
stays blocked on the tickets that exist, and its body names the fog dependency in words.

## Verify the frontier

`issue_dependencies_summary` needs ~8 s to report a fresh edge, so sleep before checking:

```bash
sleep 12 && ~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>
```

Then compare against intent: the blocked and the map must be absent, everything else
present. Claim immediately before working a ticket (`gh issue edit <n> --add-assignee @me`),
including research tickets, so the frontier does not offer them twice.

## Research tickets: brief the subagent precisely

Fire one `task` subagent per **frontier** research ticket (blocked ones wait) with
`skill://research`; keep them in a single `tasks[]` batch. In the brief:

- Findings file: the repo's existing notes convention; if the repo forbids committing
  planning material, use the gitignored design folder (`.design/research/<slug>.md`) — never
  a commit on the public repo unless the user wants the `research/<name>` branch asset.
- The comment on the ticket is a **short, answer-first resolution**: the answer, the key
  evidence, the pointer to the findings file. The full report stays in the file — do not
  paste it into the issue.
- Do not close the issue; the parent session closes it, appends the one-line pointer to the
  map's Decisions so far, and refreshes `wayfinder_view`.
- Forbid project-wide builds, formatters or test suites, and any write to the source tree
  other than the findings file.

## Closeout

`wayfinder_view repo:<owner>/<repo>` for the human, and the charting record written to
`/tmp/wayfinder-<topic>.md` and rendered with `render_html` (round text plus a
`## Settled decisions` list and the map-as-charted table). Charting resolves nothing except
the research tickets it fired.
