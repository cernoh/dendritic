---
name: travelling-deck-github-publish
description: Publish the local travelling-deck repository to GitHub when no remote repository exists
---

# Publish travelling-deck

From the clean repository root:

```sh
gh repo create cernoh/travelling-deck --public --source . --remote origin --push
```

Verify the remote and branch:

```sh
git remote -v
git status --short
git branch -vv
```

The repository URL is `https://github.com/cernoh/travelling-deck`.
