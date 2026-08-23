---
name: github-empty-repo-pr-bootstrap
description: Use when creating and autonomously shipping a GitHub repository from an empty local repo
---

## Procedure

1. Check the current branch and identify a commit suitable for the base branch.
2. Create the GitHub repository and push the feature branch.
3. If GitHub has no `main` ref, push the intended base commit with a fully qualified refspec:
   `git push origin <base-commit>:refs/heads/main`
4. Set the repository default branch:
   `gh repo edit --default-branch main`
5. Create the PR with the feature branch as head and `main` as base. Include `Closes #<issue>` in the body.
6. Merge the PR autonomously when no human review is expected.
7. Verify the PR is merged and the issue is closed. If the issue remains open, explicitly close it with the GitHub CLI.

This avoids missing-base-ref errors and prevents an apparently shipped feature from remaining only on the feature branch or leaving its tracking issue open.
