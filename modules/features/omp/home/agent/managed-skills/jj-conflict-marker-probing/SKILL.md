---
name: jj-conflict-marker-probing
description: "Probe and reason about how jj (0.45.x) resolves conflicts when a marker file is edited: the snapshot re-parse rule, the only exit-code observable, partial resolutions, plus the measurement traps that produce invalid probe logs."
---

# Probing jj conflict resolution by editing markers

Use when a design assumes "an edit that removes the conflict markers resolves the
conflict", when an app must list/poll conflicts through the `jj` binary, or when a
probe of conflict behaviour must be trusted.

## The mechanism (jj 0.45.1)

Every command snapshots the working copy first. For a path the tree records as
conflicted, jj **re-parses that file for conflict markers**:

| File on the next snapshot | Recorded |
|---|---|
| no parseable block, or a side count that does not match the conflict arity | one **plain file**: the bytes are the resolution, never validated |
| markers unchanged | the same conflict object |
| markers still parse (edits inside them count) | a **new conflict** built from the parsed sides |

So content is never checked: junk that no longer parses is committed as the
resolution. An edit that adds a line while leaving the markers intact does **not**
resolve (it is re-absorbed into the conflict; the file is not rewritten).

Source: `lib/src/conflicts.rs` `update_from_content` (the whole rule),
`lib/src/local_working_copy.rs` (snapshot caller, passes the materialized marker
length), `lib/src/conflicts.rs` `parse_conflict` (drops a block whose side count
mismatches), `docs/working-copy.md` section Conflicts (states the contract).

Parse details that matter: marker lines are a run of one of `< > + - % \ | =`,
length >= the length the working copy materialized (min 7) — **longer is accepted,
shorter is ignored**, so a comment or doc quoting a marker with fewer characters
describes something jj would not parse. Both jj-style and git-style blocks parse
regardless of the configured style.

## Observables, in preference order

- `jj resolve --list [-r <rev>]` — the only candidate whose **exit code** carries
  the answer: rows + `rc=0` when conflicted; stderr `Error: No conflicts found at
  this revision` + `rc=2` when clean. With paths: `Error: No conflicts found at the
  given path(s)`, plus `Warning: No matching entries for paths: <path>`. No `-T`
  option, so the list is text, per file (not per hunk), rows padded to the longest
  path -> split on the last `\s+(\d+)-sided conflict$`.
- `jj log -T '"conflict=" ++ json(conflict) ++ "\n"'` — per-commit boolean for a
  change list; true for descendants too (an empty `@` over a conflicted parent is
  `true`). `json({...})` with an object literal is a template syntax error; build an
  object by concatenation: `"{ \"change_id\": " ++ json(change_id) ++ ", \"conflict\": " ++ json(conflict) ++ " }"`.
- `jj status` and `jj diff` show conflicts (`Warning: There are unresolved conflicts
  at these paths:`; `Created conflict in <path>:`) but always exit 0 — never use them
  as a gate.
- Never poll with `--ignore-working-copy`: it reports the pre-snapshot state and
  still names a conflict after the file on disk is resolved.

Partial resolution stays listed at **file** granularity, keeps its remaining marker
block verbatim, and jj does not rewrite the file (md5 identical across the command).
Resolving a file that sits in an empty `@` over a conflicted ancestor lands in `@`;
`jj status` prints `Hint: Conflict in parent commit has been resolved in working
copy.` and `jj squash` moves it into the ancestor.

Side order follows how the conflict was built, not local/remote. In a rebase of the
local change onto a remote bookmark, side 1 is the rebase destination (remote), so
`jj resolve --tool :ours` keeps remote and `:theirs` keeps local; both resolve
without ever touching markers.

## Probe recipe

Build a real conflict, then vary the file and read the poll:

```bash
jj git init --colocate
jj config set --repo user.name Tester; jj config set --repo user.email t@example.com
printf 'line1\nline2\nline3\n' > notes.txt
jj describe -m BASE; jj bookmark create main -r @; jj new
jj new -m REMOTE main; sed -i '2s/.*/remote-line2/' notes.txt
jj bookmark create remote -r @                      # a bookmark, see traps
jj new -m LOCAL main; sed -i '2s/.*/local-line2/' notes.txt
jj rebase -s @ -d remote                            # -o remote gives the same conflict
jj resolve --list                                   # rows, rc=0
```

Two hunks in one file need **both sides to edit the same lines**, spaced more than
six lines apart so they stay separate hunks; edits to different lines merge cleanly
and produce no conflict at all. For a multi-file conflict, add a second path.

Variants worth measuring: resolve one hunk only; delete only the marker lines
(commits junk, jj reports it resolved); delete only the closing marker line (also
resolves, leftover marker text is committed as ordinary text); append outside the
markers (stays conflicted).

## Traps that invalidate a probe

- **Revset `description("X")` can resolve empty** in 0.45.1 (quoted string matched
  nothing, `description(substring:"X")` worked). Do not name a rebase destination
  that way: set a bookmark at the revision and use the bookmark.
- **`--config` applies to one invocation.** Setting `ui.conflict-marker-style` only
  on `jj git init` leaves the later `describe`/`new`/`rebase` calls on the default;
  use `jj config set --repo ui.conflict-marker-style snapshot` or export `JJ_CONFIG`.
  The default in 0.45.1 is `diff`, which hides one side in a `%%%%%%%`/`\\\`
  base-to-side diff; `snapshot` lists all sides with the base after a `-------`.
- **No `python3` on this host** (bash PATH). Write file mutations with `sed`/`awk`,
  and make awk line-number rules aware that a conflicted file's line numbers include
  the marker lines.
- **Whole-body issue edits race.** Concurrent sessions append to a shared map/issue
  body; re-fetch immediately before writing and re-read after.
- **Delegated prose can alter bytes.** A comment written by a subagent may shorten
  backslash runs inside a verbatim marker block; count the characters on the posted
  body before closing the ticket.
