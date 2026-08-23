---
name: travelling-deck-plugin-verification
description: Verify the travelling-deck Decky plugin with its Nix shell and backend/frontend checks
---

# Travelling Deck plugin verification

From the feature worktree:

```sh
nix develop --command bash -lc 'PYTHONPATH=backend:. python -m unittest discover -s backend/tests -t .'
nix develop --command bash -lc 'cd frontend && node --test --experimental-strip-types src/horizon.test.ts && npm exec -- tsc --noEmit'
nix flake check
```

Use `PYTHONPATH=backend:.` and unittest `-t .` because backend tests import `sensors` and use package-relative imports. The Nix flake check currently validates plugin metadata and Python compilation; run the behavioral suites separately.
