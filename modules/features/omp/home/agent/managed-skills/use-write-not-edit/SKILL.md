---
name: use-write-not-edit
description: "Always use write tool instead of edit tool for file modifications in this repo's worktrees — edit tool silently fails to persist changes"
---

# Reliable File Editing in This Repo

## Problem
The `edit` tool frequently reports success but doesn't actually modify files. The snapshot tag gets rejected as stale even immediately after a fresh read. Files revert to their pre-edit state on subsequent reads.

## Solution
Use the `write` tool to overwrite entire files instead of `edit`. This is the ONLY reliable approach.

## When to Use
- Any file modification in this repo's worktrees
- Especially for Lua files (main.lua, sync.lua, api.lua, etc.)
- When `edit` rejects with "hash not from this session" or "file changed between read and edit"

## Workflow
1. `read` the file with `:raw` to get full content
2. Modify the content in your response
3. `write` the entire file back
4. Verify with another `read` or syntax check

## Evidence
This happened repeatedly with: api.lua (test exports), main.lua (test methods), sync.lua (getQueue), flake.nix (run-tests rename). The `edit` tool appeared to apply (returned new hash) but the file on disk never changed. `write` works consistently.
