---
name: recover-default-branch-edit
description: "Recover when you've already edited files on the default branch and need to move those changes to a feature branch and open a PR without losing other working-tree edits."
---

---
name: recover-default-branch-edit
description: "Recover when you've already edited files on the default branch and need to move those changes to a feature branch and open a PR without losing other working-tree edits."
---

# Recover from editing on the default branch

Use this when you realize you've made changes on `main`/`master` and the rules require a feature branch + PR.

## Goal
Move a specific file's changes from the default branch into a new feature branch, push it, and open a PR — while preserving all other working-tree edits (including untracked files) on the default branch.

## Steps

1. **Inspect the working tree** to confirm what changed and what branch you're on:
   ```bash
   git status --short
   git branch --show-current
   ```

2. **Save the diff for only the file(s) you want to commit** on the new branch:
   ```bash
   git diff -- path/to/file.ext > /tmp/change.patch
   ```
   If the file is currently staged, use `git diff --cached -- path/to/file.ext > /tmp/change.patch` instead.
   If the file is currently untracked, use `git diff --no-index /dev/null path/to/file.ext` instead, or `git add` it first and then `git diff --cached`.

3. **Stash everything**, including untracked files:
   ```bash
   git stash push -u -m "preserve working changes"
   ```

4. **Create a clean feature branch from the default branch**:
   ```bash
   git checkout -b fix/descriptive-name
   ```

5. **Apply the saved patch**, stage, and commit:
   ```bash
   git apply /tmp/change.patch
   git add path/to/file.ext
   git commit -m "descriptive message"
   ```

6. **Push the branch**:
   ```bash
   git push -u origin fix/descriptive-name
   ```

7. **Open a PR** via the GitHub tool or `gh pr create`.

8. **Return to the default branch and restore the other edits**:
   ```bash
   git checkout main
   git stash pop
   ```

9. **Clean up any restored staged changes** (only needed if the original changes were staged):
   If the file(s) you moved were staged before stashing, `git stash pop` will bring them back on `main`. Remove them from the default branch's working tree:
   ```bash
   git reset HEAD path/to/file.ext
   git checkout -- path/to/file.ext
   # For new files/directories:
   git clean -fd path/to/new-directory/
   ```

10. **Verify** the working tree is back to the original state except the change now lives on the PR branch:
    ```bash
    git status --short
    git branch -v
    ```

## When not to use this
- If you haven't edited on the default branch yet, just create the feature branch first and edit there.
- If the user explicitly asks to push to the default branch anyway, still follow the hard rule; explain and redirect to a PR.
