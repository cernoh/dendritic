---
name: stacked-pr-squash-rebase
description: Rebase and merge stacked feature branches after squash merges with duplicate-commit skipping and CI polling
---

# Stacked PR Squash Rebase

Use when merging a stack of PRs (e.g. feat/3-ui -> feat/4-presets -> feat/5-settings) where each PR was built on the previous branch and merges are squash merges.

## Workflow
1. Merge bottom PR with `gh pr merge <N> --squash --delete-branch`. Verify with `gh pr view <N> --json state,mergedAt` + `git fetch; git checkout main; git pull --ff-only; git log --oneline -7`.

2. Check next PR status: `gh pr view <N+1> --json mergeable,mergeStateStatus`. Expect `UNKNOWN` immediately after merge, then `DIRTY/CONFLICTING` after ~10s. Poll with `sleep 10` if needed.

3. Rebase: `git checkout feat/<next>; git rebase main`. Squash duplicates cause `CONFLICT (add/add)` for files added in both branches. Fix: `git rebase --skip` for the duplicate commit(s). Then `dropping ... -- patch contents already upstream` for lint/fmt fixups automatically. Verify `git log --oneline -5` shows clean stack and `git status` clean.

4. Format check: `nix develop --command bash -c 'deno fmt --check; cargo fmt -- --check'` — expect 0. If needed `deno fmt`/`cargo fmt` and commit.

5. Push: `git push --force-with-lease`.

6. CI poll: `sleep 80; gh run list --limit 10 --json databaseId,headBranch,status,conclusion --jq '.[] | select(.headBranch=="feat/<next>")'` — wait until latest run `completed success`. Re-poll with 30-45s sleeps if `in_progress`. Old failed runs remain; match `databaseId` for latest.

7. Merge next PR and repeat from step 2 for remaining stack.

## Gotchas
- Squash merge creates new commit on main; rebasing stacked branches always needs `--skip` for the squashed commit(s).
- `mergeStateStatus` is `UNKNOWN` for ~5-10s after push/rebase — sleep before reading as `DIRTY`.
- `deno lint` with `exclude: ["src/"]` may be needed if SvelteKit `$lib` imports trigger `no-sloppy-imports`.
- Force-with-lease after rebase; delete branch on merge.
