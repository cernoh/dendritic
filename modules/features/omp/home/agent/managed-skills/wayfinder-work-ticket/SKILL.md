---
name: wayfinder-work-ticket
description: "Resolve one ticket on an existing wayfinder map (github.com/sesh/wayfinder): claim, ground the answer in repo evidence, run the grill_form rounds for HITL tickets, commission the resolution comment from issue-scribe, close, then patch the map body. Use when invoked with \"wayfinder\" plus an issue URL or number rather than a loose idea."
---

# Working a wayfinder ticket

Companion to the `wayfinder` skill (charting is a different session; see `wayfinder-chart-*` and `wayfinder-map-expansion`). This covers "user invokes with a map or a ticket URL" — one ticket per session, research tickets excepted.

## Load, claim, then read

```bash
gh issue view <n> --json number,title,body,labels,state,assignees,url   # the ticket
gh issue list --state all --label wayfinder:map --json number,title,state
bash ~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>          # open, unblocked, unclaimed
gh issue edit <n> --add-assignee @me                                    # the claim, first write
```

The map body carries Destination, Notes, Decisions so far, Not yet specified, Out of scope. Read it once per session — it names the skills, the gates and the standing preferences.

Per-ticket dependency depth (who blocks whom) comes from the API, not the sub-issue list:

```bash
for n in 9 10 11 12; do echo -n "#$n blocked_by="; gh api repos/<owner>/<repo>/issues/$n/dependencies/blocked_by --jq '[.[].number]|join(",")'; done
```

## Ground the answer in the repo first

A grilling ticket's value is the evidence a session brings. Measure before asking, so each recommendation carries facts the human cannot get by reading the ticket.

Sizing a tier list (the ticket usually demands tiers "sized so one session can complete a tier"): the skill's own estimate is often wrong — a self-written tier list of 20,000 lines is four sessions. Measure per family:

```bash
git ls-files 'app/src/main/**/*.kt' | xargs wc -l | sort -rn | sed -n '1,45p'   # biggest files
# then totals per family directory
for d in ui/component ui/page/settings ui/page/tools; do printf '%-24s ' "$d"; git ls-files "app/.../$d/*.kt" "app/.../$d/**/*.kt" | sort -u | xargs wc -l 2>/dev/null | tail -1; done
```

Verify "dead file" claims instead of trusting them — dead code is transitive:

```bash
git grep -n 'SymbolName' -- app/src/main | grep -v '<its own file>'   # no live hits = dead
git grep -n 'R\.anim' -- app/src/main/res app/src/main/java          # unreferenced anim XMLs
```

Check defaults, not just presence: a theme flag read as `kv.decodeBool(KEY, true)` is the **default** look, which moves its deletion earlier or later in the tier order.

## The grill loop

`grill_form` carries the whole round, one decision per question, most important first, each with a recommendation and short `choices`. End the turn with one line naming the returned URL; the submit arrives as the next user message.

- Round 1 answers carry the ticket's own numbered asks (prepend the recommendation with the evidence in the body).
- The next round exists to fix **defects in your own earlier recommendations** — e.g. a tier too large for one session, or two answers that now contradict each other (a boundary declared "shippable" then narrowed to debug-only). Say so plainly in the intro; it is the reason to ask again.
- Overruled recommendations: accept, execute, and stop arguing. If the override opens a gap (debug at every boundary leaves the release build unchecked), that gap is the next round's question.
- Write the round text to `/tmp/wayfinder-<topic-slug>.md` as you go, with a glossary of the terms the plan fixes (tier, gate, exit condition, old language, ledger) and a `## Settled decisions` list per round. `render_html` it as the reading copy.

## Record the resolution

Rule 7 applies: the resolution comment states decisions and acceptance criteria, so the `issue-scribe` agent writes it. Dispatch with `task` (blocking), giving the brief in full — the scribe has no session context:

- repo, ticket number and title;
- the sections in order, each with its content (tables, file paths, line numbers);
- "keep paths, identifiers and line numbers verbatim; STE applies to the prose";
- post with `gh issue comment <n> --body-file <file>`, do not close the issue, do not touch repository files, report the URL and the lint total.

STE lint counts a Markdown table as one long paragraph and flags the passive-ish cells; the scribe's fix is to convert the table to a list. Expect that.

Then, in this order:

```bash
gh issue comment ...                                                    # by the scribe
gh issue close <n> --reason completed
gh issue edit <map> --body-file /tmp/map-new.md                          # Decisions so far + fog
wayfinder_view                                                           # refresh the page
bash ~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>           # wait ~8s after new edges
```

Map patch, by name never by bare id:

- append to **Decisions so far**: `- [<ticket title>](url): <one-line gist>`;
- **clear any fog patch the answer resolved** from Not yet specified — a decided question lives in its ticket, not in the fog;
- leave the remaining fog, and add a ticket only if the answer made a *new precise question* visible.

Map body surgery is easiest with the JS eval kernel (`read`/`write` are async there — `await read(...)`; the Python kernel may be unavailable). Slice out the changed region and assert the anchors exist before writing.

## Traps that cost time

- The `edit` tool fails with "path must be a string" when `path` is omitted — the error names a validation failure, not your `old_string`.
- `gh` invoked with cwd outside a git repo ("failed to run git: fatal: not a git repository") — pass `--repo <owner>/<name>`.
- The frontier lag is real: a freshly wired edge takes ~8 s to move a ticket between takeable and blocked.
- `gh issue list --label wayfinder` matches nothing; labels are `wayfinder:map`, `wayfinder:grilling`, `wayfinder:prototype`, `wayfinder:research`, `wayfinder:task`.
- The scribe's report is a JSON blob with an `acceptance` map — read it to confirm `issue_<n>_still_open` and the lint total rather than assuming.
- Verify the comment you paid for: `gh issue view <n> --json comments --jq '.comments[-1].body'`.
