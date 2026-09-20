---
name: github-issue-body-safe-rewrite
description: "Safely append to or rewrite a long GitHub issue body (wayfinder map indexes, spec issues) from an agent session: the read-tool line elision that silently deletes settled decisions, the fetch-splice-edit recipe, and the write proof."
---

Issue bodies have no recoverable history. A rewrite that drops content destroys a settled decision
permanently, and the drop is silent: nothing in `gh issue edit` reports that text disappeared.

## The hazard

`read` elides any line longer than roughly 768 bytes, showing a `…` tail. A wayfinder map's
Decisions-so-far entries are often a single long line. An agent that reads the body, then rebuilds it
from what it saw, silently truncates every long entry it touched.

Same class of loss: reading the body through a display tool that wraps, trims, or paginates.

## The recipe

Never rebuild an issue body from a read. Fetch it as bytes, splice, write back.

```bash
gh issue view <n> --repo <owner>/<repo> --json body --jq .body > /tmp/issue-<n>.md
wc -c /tmp/issue-<n>.md            # record before
```

Splice the new content into that file instead of retyping the document:

- Append one line: insert after an anchor line you can match uniquely.
- Prefer a real edit over a heredoc rewrite; a heredoc retypes every line and reintroduces the hazard.

```bash
gh issue edit <n> --repo <owner>/<repo> --body-file /tmp/issue-<n>.md
```

## The write proof

Three checks, all cheap:

1. `wc -c` grew by exactly the appended bytes (within the newline count).
2. Fetch again and compare the untouched lines against the pre-edit copy: they are byte-identical.
3. Grep for one unique token of the new content, and for one unique tail of the longest pre-existing
   line, to prove the long line survived.

```bash
gh issue view <n> --repo <owner>/<repo> --json body --jq .body > /tmp/verify-<n>.md
diff /tmp/issue-<n>.md /tmp/verify-<n>.md     # empty
```

## Concurrent writers

Another session may edit the same body between your fetch and your write. Fetch immediately before the
write, keep the fetch → splice → edit chain short, and verify afterwards. On a collision you have
overwritten the other session's line; re-read the body and re-apply the missing entry from its ticket.

## Wayfinder maps

A map's Decisions-so-far is an index of one line per closed ticket. Append the new line after the last
existing entry and leave every other line untouched; when the map's decision lines are long, the
byte-identical check on lines 1..n-1 is the proof that no earlier decision was lost.
