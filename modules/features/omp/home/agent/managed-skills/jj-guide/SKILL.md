---
name: jj-guide
description: "Reference for unfamiliar or complex jj operations, command translation, revsets, rewriting, repository diagnosis, or recovery. Use for lost work, bookmark errors, conflicts, divergence, stale workspaces, or operation-log forensics. Do not activate for routine status, diff, log, workspace creation, or shipping tasks covered by dedicated skills."
---

# jj Guide

Vendored from `plasticbeachllc/jj-skipper` v0.7.1 (`shared/skills/jj-guide`). Local edits: `skill://` link targets and the delivery note below.

Use this skill only when the task needs more than routine `jj st`, `jj diff`, or `jj log`, and is not fully covered by `jj-workspace` or the repository delivery rules.

## Invariants

- The working copy is commit `@`; edits automatically amend it.
- There is no staging area.
- Use `-m` for descriptions and commits; never open an editor or use `-i`.
- Prefer stable change IDs over commit IDs.
- After `jj commit -m "msg"`, committed content is at `@-` and the new `@` is empty.
- Conflicts live in commits. The operation log makes repository operations recoverable.

## Load only what the task needs

- Git command translation: [references/git-to-jj.md](skill://jj-guide/references/git-to-jj.md)
- Bookmarks, syncing, rewriting, review, and selective changes: [references/workflows.md](skill://jj-guide/references/workflows.md)
- Revsets and filesets: [references/revsets-filesets.md](skill://jj-guide/references/revsets-filesets.md)
- Repository diagnosis, lost work, divergence, conflicts, or stale state: [references/recovery.md](skill://jj-guide/references/recovery.md)

Do not read every reference. Select the narrowest relevant one.

For isolated workspace creation, use `jj-workspace` (this repo also provides `dojjo`). For commit, push, and pull-request delivery, follow the repository branch and pull-request rules. A colocated repository keeps `.git/` in sync, so `gh` and read-only Git commands stay valid; make history changes with `jj` only.
