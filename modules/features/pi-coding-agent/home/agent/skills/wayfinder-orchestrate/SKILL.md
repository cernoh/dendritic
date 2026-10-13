---
name: wayfinder-orchestrate
description: "Drive a wayfinder map to done: fan its tickets out to herdr agents in isolated worktrees, watch for stalls, land PRs that close their issues, and route every human decision through one deferred-answers log."
disable-model-invocation: true
---

Wayfinder charts the map; this skill walks it. Invoked with a map, you become the **orchestrator**: every frontier ticket gets claimed and driven in its own herdr pane on its own worktree, you hold the watch (stalls, model switches, resolutions, newly unblocked tickets), implementation tickets land as PRs that close their issues, and every question that needs a human parks in one deferred log with you as the conduit. You never answer for the human, and you never leave a ticket claimed-but-silent.

Refer to maps and tickets by **name**, never a bare number, in everything the human reads.

## 1. Take the mandate

The user invokes with a map (URL, number, or path). Then:

1. Read the repo's `docs/agents/issue-tracker.md`, section "Wayfinding operations" — it fixes how _this_ repo expresses map, child, blocking, frontier, claim, and resolve. GitHub and local-markdown trackers differ; follow the file, not your priors.
2. Load the map body: **Destination**, **Notes** (skills every session consults, standing preferences), **Decisions so far**, **Not yet specified**, **Out of scope**.
3. Enumerate the open tickets and compute the **frontier**: open, unblocked, unclaimed children.

Done when the Destination is statable in one line, the tracker ops for this repo are known, and every open ticket is sorted into frontier or blocked.

## 2. Prime with evidence

Before any pane spins up, recover what this host already decided so no ticket re-derives it and no human re-answers it:

1. Load the `funes-recall` skill. Recall against the Destination and each frontier ticket's question (2–3 angles each); every hit is a pointer, so `get` the cited range before treating a passage as a decision.
2. Read the repo context the Notes name (`CONTEXT.md`, ADRs per `docs/agents/domain.md`).
3. Condense per ticket: the verified facts, constraints, and rejected alternatives its pane needs — this becomes the **brief's evidence block**, with the source sessions named so the pane can zoom.

Done when each frontier ticket carries an evidence block, and nothing the memory already answered is slated for re-research or re-asking.

## 3. Fan out the frontier

**Claim first**, then spawn — the claim is what keeps concurrent sessions off each other's tickets.

- **AFK tickets** (`research`, AFK `task`): claim it, then `herdr_spawn_agent` with `name` after the ticket and `isolated: true` (its own worktree, one writer per worktree). The brief holds the ticket question, the evidence block, the repo conventions, and the resolve protocol: post findings as a ticket comment, link assets (branches, files), never close the ticket — closing is the orchestrator's act.
- **HITL tickets** (`grilling`, `prototype`, HITL `task`): the judgment stays human. Fan out only the legwork a pane can do alone (a prototype artifact build, a fact-gathering pass), then park the decision itself in the deferred log (step 5). A grilling is never fanned out: you run it yourself, in session, through the `grilling` and `domain-modeling` skills, rendering each round per the artifact channel.
- Coordinate through the tracker alone. Never touch another session's worktree.

Done when every frontier ticket is claimed and either driving in a named pane or parked in the deferred log — none merely open.

## 4. Hold the watch

This is the loop you live in until the map is done. Sweep the fleet with `herdr_list_agents` on a steady cadence and read pane tails. Every sweep ends with each pane in exactly one of these states:

| Signal | Response |
|---|---|
| Driving (fresh output, progress toward the brief) | Leave it alone. |
| `blocked` on a question for the human | Route it to the deferred log (step 5). Never answer it yourself, even to unstick the pane. |
| **Stalled** (no output and no state change ~15 min, scaled to ticket size) | Nudge via `herdr_message_agent`; still silent → `herdr_interrupt_agent` and redirect with a sharpened brief; still silent → `herdr_resume_agent`, else re-spawn. |
| `gone` (crashed, errored, pane closed) | Resume on its retained session; if resume fails, re-spawn. |
| Thrashing (output flows, direction wrong) | Sharpen the brief once on the same model; if the failure is capability-shaped (reasoning depth, not missing context), **switch models** and re-spawn. |

**Model switches and re-spawns carry the trail**: the ticket's comments, the partial branch commits, the evidence block, and why the last attempt failed — a fresh pane starts from the trail, never from zero. Record each switch and its reason on the ticket. Retry on the same model first; escalate only on capability-shaped failure; spend a cheaper model on pure legwork.

As panes report: record each resolution (answer as comment, close, Decisions-so-far pointer per the tracker ops), graduate fog the answer made specifiable (create-then-wire), rule out-of-scope tickets out rather than resolving them, and fan out newly unblocked tickets back through step 3.

Done when no ticket sits claimed-but-silent, every resolution is on its ticket and the map, and the frontier is either driving or empty.

## 5. Defer to the human (the conduit)

Anything needing a human — HITL judgments, `blocked` pane questions, ambiguous calls, destructive or scope-changing moves — parks in one place: a `## Deferred to human` section on the map itself, updated in place, one line per item:

```markdown
- [<ticket name>](link): <the question> — awaiting | answered <date>
```

Post a comment on the ticket pointing at the deferred line, so the question lives with its ticket and the log lives in one place. Present deferred items to the human in batches, in chat; when an answer comes back, carry it to the ticket as a comment, flip the line to answered, and resume the parked pane with the answer in its trail.

Done when zero open questions were answered by an agent, and every human answer is collated on the map and carried back to its ticket.

## 6. Land the code

Implementation-bearing `task` tickets resolve as branches, not just decisions:

1. The pane works its ticket's branch in its own worktree: `wayfinder/<number>-<slug>`; implements per the ticket's resolution; verifies per repo convention (tests, typecheck, lint).
2. GitHub tracker: push the branch and `gh pr create` with `Closes #<ticket>` in the body alongside a link to the resolution comment — merge then closes the issue itself. Local-markdown tracker: no PR exists; append the branch name and patch summary to the ticket instead.
3. Review findings route back through the same pane, on the same branch, until green.

Done when every implementation ticket has a green PR that closes its issue on merge (or a merged PR), and the ticket links it.

## 7. Done

The map is done when no tickets are open, the fog is empty or ruled out, every implementation PR is merged (or explicitly left open with its reason noted on the ticket), and the deferred log is fully answered. Report the route walked — ticket names, their one-line answers, the PRs, the deferred answers — and link the map.
