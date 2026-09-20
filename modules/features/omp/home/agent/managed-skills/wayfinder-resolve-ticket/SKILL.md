---
name: wayfinder-resolve-ticket
description: "Resolve one ticket of an existing wayfinder map (a GitHub issue labelled wayfinder:*) end to end: claim, dispatch the research work with a parallel fixture builder, verify the deliverable against real runs, record the resolution, and graduate the newly specifiable fog. Use when invoked with a wayfinder ticket URL or number, or when working a map's frontier."
---

# Resolving one wayfinder ticket

One ticket per session (research tickets excepted). The named ticket wins over the frontier order.

## 0. Orient

1. `gh issue view <n>`: the ticket. `issue://<map>` for `wayfinder:map`: the map body only.
2. `~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>`: the takeable tickets.
3. Read the map's `## Notes` named skills, the design record or source material it names, and the
   `.design/research/*.md` files of already-closed tickets. Do not re-open a settled decision.
4. Read the remaining open ticket bodies once; the fog-judgement at step 6 needs them.

## 1. Claim

`gh issue edit <n> --add-assignee @me` — the session's first write.

## 2. Dispatch

- **Research ticket** → one `task` subagent for the whole deliverable: one coherent file, one
  agent. Splitting by surface fragments the cost tables and races on the file.
- **Pair it with a mechanical fixture builder** (`agent: "sonic"`) when the ticket needs
  brute-force inputs. Fix the sizes and paths in the batch `context`, not in negotiation, and
  give the builder a `READY` sentinel (`status=building` first, then `status=ready` plus verified
  `KEY=value` numbers) so the researcher polls instead of blocking. 20k commits via one
  `git fast-import` stream plus `jj git init --colocate` import, not 20k `jj` calls.
- Brief the researcher with the deliverable path, the per-surface acceptance, the measurement
  method (capture the real output, then time both a `serde_json::Value` and a typed-struct parse
  in release and debug), and the house style of the precedent files.
- Keep out of the subagent's way: it reports a summary; you verify.

## 3. Verify the deliverable (never skip)

Claimed artifacts are unverified. Rerun the load-bearing numbers yourself:

1. Re-run the doc's own harness if it left one (`verify-doc.sh`-style scripts reproduce the
   printed shell blocks) and compare against the doc's figures.
2. Rebuild and rerun any benchmark (`nix develop <repo> -c bash -c 'cd <bench> && cargo build
   --release'` — a warm registry makes this seconds).
3. Re-run every quoted **command → output/error pair**. This is the main defect class: the prose
   numbers usually hold, the quotes drift, and a wrong pairing survives a normal read.
4. Spot-check fixtures with an independent command and compare with the sentinel's numbers.
5. Check `git status --short` is empty when the work is meant to be gitignored-only.

On one confirmed defect, do not hand-fix a line: send the agent the defect and demand a same-class
sweep of the whole file, then require a mechanical checker (extract every `$ `-prefixed block, run
it through bash in sequence so `cd` carries, require each literal output line to appear in order,
`...` as a wildcard for elided ids) and a report of every line changed with its proof. Confirm the
report file is newer than the document before trusting it.

## 4. Record the resolution

- **Issue prose goes through `issue-scribe`** (rules: every issue body, comment, and title).
  A task subagent that posts its own comment is a deviation: check the lint yourself before
  spending a scribe pass, and never re-post a lint-clean comment.
- Lint with `nix shell nixpkgs#python3 --command python3 ~/.omp/agent/scripts/ste-lint.py <
  <file>` — host NixOS usually has no `python3`. File arguments print a summary only; use stdin
  for the rule breakdown. `total` is the number to drive to 0; the link label may keep the
  ticket's possessive even though `contraction` fires on it.
- `<ticket>` → resolution comment (short: the commands, the decisive numbers, the pointer to the
  long-form file), then `gh issue close`, then one line in the map's `## Decisions so far`.

## 5. Edit the map body safely

Parallel sessions edit the same tracker. Re-fetch `gh issue view <map> --json body -q .body`
immediately before the write, splice by anchor (`\n## Not yet specified`, the `- **DOX indexing.**`
bullet), write a temp file, `gh issue edit <map> --body-file`, then re-fetch and `diff` — GitHub
adds one trailing newline, nothing else may change. Keep 3+ newline runs unchanged. Refer to a
ticket by its name, never a bare number, and gist the answer without restating the ticket's detail.

## 6. Graduate the fog

- A question the answer made **sharp** → a new child ticket: create with the `wayfinder:<type>`
  label, then attach `gh api --method POST repos/<owner>/<repo>/issues/<map>/sub_issues -F
  sub_issue_id=$(gh api repos/<owner>/<repo>/issues/<child> --jq .id)`.
- A question still **unsharp** → one added line in `## Not yet specified`; check any section
  reference it carries against the final document.
- A ticket now past the destination → close it and put one line in `## Out of scope`.
- Sleep ~9 s before the next frontier query: a fresh dependency edge takes that long to appear.

## 7. Close out

`wayfinder_view` (`map`, `repo`) renders the live page: report that URL and the solved/left
counts. Work that touched only a gitignored directory owes no DOX pass; say so instead of
skipping it silently. State the one next frontier ticket and, when it is HITL, that it needs the
human's session.

## Traps

- A `task` subagent inherits the repo but not the conversation: restate the constraint set
  (no tracked files, no commits, no network assumptions, the exact jj/binary version, the
  `timeout`/`async` escape from the 300 s bash deadline).
- The researcher's own summary is not evidence: reproduce the headline numbers before writing the
  map line.
- An unbounded cost figure in a deliverable is only useful with the bounded alternative beside it.
- Fixtures under `.design/<...>/fixtures/` plus their sentinel are the evidence the resolution
  comment points at: keep them, do not clean them up.
