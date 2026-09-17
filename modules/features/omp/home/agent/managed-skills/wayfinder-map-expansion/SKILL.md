---
name: wayfinder-map-expansion
description: "Expand a GitHub wayfinder map with sharp labeled decision tickets and correct fog-of-war bookkeeping, using the verified sub-issue, blocked_by, and frontier command set"
---

Use the canonical map issue as the low-resolution source. Create only questions that are precise enough to ticket now; leave unresolved broader areas in Not yet specified. Label every child with wayfinder:<type>. Create tickets first, then wire native GitHub blocking dependencies in a second pass using blocker database IDs. Update the map so graduated fog is removed and only genuinely un-ticketable handoff fog remains. Verify frontier queries surface every open, labeled, unblocked, unclaimed ticket.

## Verified command set (2026-09-17, cernoh/dendritic + cernoh/reddit-idea)

Both the child link and the blocking edge need the target issue's **database id**: `gh api repos/{o}/{r}/issues/{n} --jq .id`. The `#number` and the `node_id` both fail.

- Attach a child to the map: `gh api --method POST repos/{o}/{r}/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`; read it back with `GET .../issues/<map>/sub_issues`. Both issues must share the repository owner. Reorder the map with `PATCH .../issues/<map>/sub_issues/priority -F sub_issue_id=<id> -F after_id=<id>`.
- Wire a blocker: `gh api --method POST repos/{o}/{r}/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, reversed with `DELETE .../dependencies/blocked_by/<issue_id>`, listed with `GET .../dependencies/blocked_by`.
- Frontier: open issues carrying a `wayfinder:` label, minus the map, with `.issue_dependencies_summary.blocked_by == 0` and no assignee. `blocked_by` counts **open** blockers only, so it is the live gate. The tested implementation is `~/.omp/agent/scripts/wayfinder-frontier.sh [<owner>/<repo>]` in the dendritic tree (`modules/features/omp/home/agent/scripts/`); run it instead of retyping the jq.
- Clean up a probe issue with GraphQL `mutation { deleteIssue(input: {issueId: "<node_id>"}) { clientMutationId } }`; a deleted issue then answers 410 to REST reads.

## The lag that makes a single read lie

A freshly created blocking edge is not visible at once. Measured: `issue_dependencies_summary.blocked_by` read 0 at t=2s and 1 at t=8s, and the frontier query listed the just-blocked ticket in that window. Poll the frontier after wiring rather than reading it once, or a blocked ticket looks takeable.
