---
name: wayfinder-grilling-ticket-rounds
description: "Run the multi-round grill_form loop on a wayfinder HITL inventory ticket: measure first, one decision per question with file:line evidence, per-round record file, ask for the ledger/boundary/deferral decisions the ticket text omits, publish the deliverable to a research branch and render it for the acceptance round, then hand off to issue-scribe. Use when a wayfinder ticket needs decisions (inventory, plan, contract) rather than a single research file."
---

# Running a wayfinder grilling ticket over several rounds

Companion to `skill://wayfinder-ticket-evidence-grounding` (measures the surface before the first round) and
`skill://wayfinder-resolve-ticket` (claim, verify, record, graduate). This file covers the loop between them:
a ticket whose deliverable is a *set* of decisions, not one research file.

## The loop

1. **Measure before the first round** (grounding skill steps 1-3). Fan out read-only scouts per component
   family: one for the instrumented widgets, one for the row/preference DSL, one for icons and assets. Brief
   each with "every claim carries file:line, split production call sites from `@Preview`-only, three
   hardest-to-reproduce behaviours in a closing table". A production-vs-preview split is decisive: it turns a
   scary component into a one-file edit.
2. **Measure the dependency side yourself.** The replacement candidates' existence and opt-in markers are the
   other half of every recommendation. For AndroidX: download the sources jar for Kotlin visibility and the
   AAR, then `javap -v -p` for `RuntimeInvisibleAnnotations` (opt-in markers are BINARY retention). A JDK needs
   `nix shell nixpkgs#jdk21`. `@OptIn(X::class)` on a declaration means *it calls* an experimental API;
   `@ExperimentalXApi` on it means *callers* must opt in — do not confuse the two.
3. **One decision per question**, each with: measured body, a recommendation first, 3-4 short choices. Cite
   `file:line` in the body — a later session re-reads the round as the ticket record.
4. **Keep a record file** (`/tmp/wayfinder-<slug>.md`): the round's questions, then a `## Settled in round N`
   list as each answer lands. Append; never rewrite earlier rounds.
5. **Recompute the frontier after every answer**, then ask the questions the *previous answers created*. The
   rounds are not a fixed list; each answer can open the next one.
6. **Final round = acceptance of the published artifact.** Build the deliverable (the table the ticket's
   acceptance criterion names), publish it, render it, and ask the human to accept it or name the rows whose
   cost they reject. Offer 2-3 concrete likely objections as choices, not just "accept".

## Questions the ticket text omits but the deliverable needs

Ask these explicitly; they are not derivable from the ticket and each can invalidate a tier plan.

- **The inventory's boundary.** The ticket names some items and then says "for each thing in the app". Ask how
  wide the table runs, and list the unnamed families the examination found, because a table that describes a
  screen's composite row twice will fight the screen tiers that own it.
- **The ledger vocabulary.** If a downstream plan's exit condition reads "every row reads migrated", ask for
  the full status set. Four worked here: `migrated`, `deleted (dead)`, `deferred (<gate>)`,
  `stays (no equivalent)`. A two-status ledger cannot tell "not done yet" from "must never be done".
- **Every deferral's ledger status.** When an answer says "adopt X only when <other ticket> settles", ask the
  follow-up in the next round: what does the ledger say meanwhile, and does the deferral block a tier exit?
- **The re-migration set.** If the answer defers a component to a version decision, ask which fallbacks are
  worth a second migration once that decision lands. Recording this stops the other ticket reopening the
  inventory.
- **A boundary row for the wrapper layer.** Thin wrappers over library controls (`Chips`, `Buttons`, `TextField`
  in this repo) are a carrier for the app's policy, not a rewrite; give them one row with "keep live, delete
  dead" rather than a migration tier.

## Traps

- **The form echoes the recommendation in the answer text.** `<choice><recommendation>` concatenated means the
  human picked the recommended option; read the first verb, not the echo.
- **A captured "automated capture turn" is not an answer.** Never continue a round from it.
- **Do not resolve the ticket in the same turn as the round.** The submit arrives as the next user message.
- **Publish the deliverable outside `main`.** Research branches (`research/ticket-<n>-<slug>`) are the artifact
  home in these repos; commit, push, then render the markdown with `render_html` and put the rendered path in
  the acceptance question's body so the human reads the real file.
- **A `git push -u` on a new branch prints a PR-create hint** — ignore it for a research branch; the branch is
  a research asset and must not be merged.
- Keep the round count honest: two or three rounds of sharp decisions beat one round of twenty questions, and
  the acceptance round only exists once the artifact is readable.

## Close out

`grill_finish`, then route the resolution comment through `issue-scribe`, close the ticket, splice one line
into the map's Decisions-so-far, and graduate the fog: settle what the answers made sharp, add one line for
what stayed unsharp.
