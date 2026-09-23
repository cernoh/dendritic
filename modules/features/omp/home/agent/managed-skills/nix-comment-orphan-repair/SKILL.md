---
name: nix-comment-orphan-repair
description: Repair orphaned comment bullets after hunk CUTs in nix files
---

# Nix comment orphan repair

After CUT edits that remove comment hunks, re-read the touched region and check for orphaned continuation lines (indented `#` lines whose parent bullet was deleted). Restore the parent bullet line or reword the continuation into a standalone comment. Also verify `let ... in` wrappers and unused params (`config`, `pkgs`) after removing the code that used them. Parse with `nix-instantiate --parse` afterward.
