---
name: wayfinder-chart-github-mechanics
description: "Chart a wayfinder map on a GitHub repo: the pre-flight checks (fork with issues disabled), label setup, the sub-issue and blocking-edge REST calls with database ids, the frontier lag, and the grill_form question schema trap. Use when invoked with the wayfinder skill on a repo, before the first issue write."
---

# Charting a wayfinder map: the mechanics that cost time

Companion to `skill://wayfinder`. That skill holds the method; this holds the GitHub and tool traps that surface while executing it.

## Pre-flight, before any write

1. **Issues may be disabled.** A fork usually has `hasIssuesEnabled: false`, and every `gh issue create` then fails with `the '<owner>/<repo>' repository has disabled issues`.
   ```bash
   gh repo view <owner>/<repo> --json hasIssuesEnabled,isFork,parent,viewerPermission
   ```
   With `viewerPermission: ADMIN`, enable them once:
   ```bash
   gh repo edit <owner>/<repo> --enable-issues --accept-visibility-change-consequences
   ```
   Enable the map's tracker only on the repo the effort owns; do not reach for the upstream parent.

2. **Check the current branch before charting.** A map is issues, not commits, but charting often happens on the default branch. Charting itself needs no branch; any code work that follows does.

3. **Record the destination in a file, not a heredoc.** `gh issue create --body-file <path>` keeps backticks, pipes and mermaid intact. Write the body with the file tool.

## Labels

Run the five `gh label create` commands from the skill once per repo. `gh label list --search wayfinder` can lag a few seconds behind creation and show a short list; re-run rather than recreating, and expect `already exists` on a retry (exit 1, harmless).

## Issue creation order

Map first, then children: a child needs the map's number only for the sub-issue call, but the frontier script sorts by sub-issue order, and the child's own number is what you cite.

```bash
gh issue create --title "<destination>" --label wayfinder:map --body-file /tmp/wf-map.md
gh issue create --title "<question>"     --label wayfinder:<type> --body-file /tmp/wf-t1.md
```

Ticket bodies carry `## Question` only. Keep the answer out; it lands as a resolution comment.

## Sub-issues and blocking edges need database ids

Numbers are not ids. Fetch the id per issue:

```bash
gh api repos/<owner>/<repo>/issues/<n> --jq .id
```

Attach a child to the map:

```bash
gh api --method POST repos/<owner>/<repo>/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>
```

Wire a blocking edge on the **child**, naming the **blocker's** db id:

```bash
gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>
```

Verify both directions, because the POST returns the child's own number, not the edge:

```bash
gh api repos/<owner>/<repo>/issues/1/sub_issues --jq '.[].number'
gh api repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by --jq '[.[].number]|join(",")'
```

Sub-issues require the same repository owner for parent and child.

## The frontier query lags

`issue_dependencies_summary.blocked_by` counts **open** blockers, so it is the live gate. A freshly wired edge can take ~8-12 s to appear; sleep before the first query or the script reports tickets as takeable that are not.

```bash
sleep 12; ~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>
```

Cross-check the printed set against your design: every ticket you meant to be takeable, and no others.

## `grill_form` question schema

Each question object **requires a `title`** (the decision, written as a question) in addition to `body`, `choices` and `recommendation`. Omitting it fails the whole call with one validation error per question and no round is opened. A `choices` array is optional when the question is open-ended.

After the call, end the turn with one line naming the returned URL and nothing else: the form's submit arrives as the next user message.

## Charting several maps in one session

The user may ask for two efforts in one breath and then choose separate maps. Chart them one at a time: settle the first map's frontier, create its map and tickets, wire the edges, fire the research subagents, then open the second map's frontier round. Do not interleave ticket creation between the two.
