---
name: dendritic-handoff-docs
description: "Where and how to write handoff documents in this repo (.planning/handoff.md, gitignored, with status/root-cause/fix/verification structure)"
---

# Handoff docs in dendritic repos

When the user asks for a "handoff" (doc) in `~/.config/dendritic`:

1. Write it to **`.planning/handoff.md`** (user's chosen location; create dir).
2. Ensure `.planning/` is in `.gitignore` and COMMIT the `.gitignore` line to main — the doc itself stays untracked/local only.
3. Structure that worked (keep it):
   - Status-at-handoff header (branch/commit, lock revs, what was already proven green)
   - Root cause (verified evidence chain, not guesses)
   - The fix, with exact copy-pasteable code/config
   - Workaround until fixed
   - Verification recipe: runnable commands + expected outputs
   - Gotchas (unfree deps, benign warnings)
   - References: issue/PR numbers, commit SHAs, file paths, related skills

Keep the doc self-contained: the reader may be another agent session with zero context of this conversation.
