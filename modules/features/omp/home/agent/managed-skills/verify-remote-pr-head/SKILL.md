---
name: verify-remote-pr-head
description: Verify pushed feature branches before creating GitHub pull requests
---

## Procedure

1. From any checkout, run `git ls-remote --heads origin <feature-branch>`.
2. Confirm the expected commit SHA and branch ref are present.
3. Create the PR with explicit `head=<feature-branch>` and `base=<default-branch>`.
4. Search or inspect the resulting PR to confirm its head and base are correct.
