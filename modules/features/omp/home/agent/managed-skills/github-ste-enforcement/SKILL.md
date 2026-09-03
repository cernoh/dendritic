---
name: github-ste-enforcement
description: "Add GitHub Actions enforcement of Simplified Technical English (STE) for issue and PR bodies in a repository — vendored linter, failing check, comment lifecycle, templates. Use when asked to \"enforce STE writing\", \"lint issues/PRs\", or add a writing-quality gate to another repo."
---

# GitHub STE Enforcement

Gate issue and PR prose with the heuristic STE linter from the `ste-writing` skill. Reference implementation: `cernoh/dendritic` PR #117 (`.github/workflows/ste-write.yml`).

## Before you start

1. Check you can push to the target repo: `gh repo view <owner>/<repo> --json viewerPermission`. If it reports READ, you cannot open a branch or push — use a fork + PR (subject to the owner's policy), or hand the procedure to the repo owner. Do not start the issue/branch flow on a repo you cannot write to.
2. Decide the gate with data, not vibes. Lint a sample of the repo's existing issue and PR bodies first (e.g. `gh api "repos/<owner>/<repo>/pulls?state=all&per_page=40"`). In the reference repo only 1 of 80 bodies passed with zero violations — zero tolerance is a real, breaking gate, which is the point. Keep `total == 0` unless the user explicitly asks for a threshold.

## Files to add

1. `.github/scripts/ste-lint.py` — vendored copy of `~/.omp/agent/scripts/ste-lint.py` (CI must not depend on a local path).
2. `.github/workflows/ste-write.yml` — event-driven lint check.
3. `.github/ISSUE_TEMPLATE/issue.yml` — form with a `required: true` STE compliance checkbox (GitHub blocks submission otherwise).
4. `.github/pull_request_template.md` — STE guidance; GitHub prefills PR bodies from it, so the check lints the template text itself.

## Workflow design

- Triggers: `pull_request: types: [opened, edited, reopened]`, `issues: types: [opened, edited]`. Body edits re-trigger via `edited`.
- Permissions: `contents: read`, `issues: write`, `pull-requests: write`; set `GH_TOKEN: ${{ github.token }}`.
- Extract title+body from `$GITHUB_EVENT_PATH` with `jq --arg k "$kind" '.[$k].title // ""'` where `$kind` is `pull_request` or `issue` (from `$GITHUB_EVENT_NAME`). Do NOT use `.pull_request.title // ""` unconditionally — jq errors indexing a missing node for the other event type.
- Fail the step (`exit 1`) when `total > 0`; print the report JSON so the author sees exact violations.
- Comment lifecycle on the issue/PR comments endpoint (same URL for both): marker prefix `<!-- ste-lint -->`, find existing marker comment, PATCH to update, POST on first failure, DELETE once fixed. Prevents comment spam on repeated edits.
- Skip bot authors: `case "$author" in *\[bot\]*) ...` — MUST escape the brackets. `*[bot]*` is a glob character class matching any string containing b/o/t (caught every author in testing).

## YAML gotchas

- The `run: |` block: continuation lines MUST stay indented to the block base. Column-0 lines terminate the literal block and break YAML (`could not find expected ':'`).
- A multi-line bash variable assignment like `report="$marker\n<lines at column 0>\n"` is fine for bash but breaks YAML. Build with `printf '%s\n\n%s\n' "$marker" "..."` — no literal newlines, no indent leakage into the posted markdown.

## Local verification (before pushing)

1. Extract the `run:` block to `/tmp/ste-test/run.sh`; stub `gh` (`#!/usr/bin/env bash` — NixOS has no /bin/bash) to log calls and emulate `--jq` for the comment lookup; supply python3 via `nix build nixpkgs#python3 --no-link --json`.
2. Run the script from the repo root (it uses checkout-relative `.github/scripts/` paths) against fabricated event JSONs; assert exit codes: clean=0, violation=1, bot=0; assert POST/PATCH/DELETE choice per case.
3. `act` dry plan both events; real act run works until the `gh` step (act images lack gh — expected; GitHub runners preinstall it).
4. Lint every template/issue/PR draft with the vendored linter before submitting — the enforcement must pass its own gate (zero violations).

## Notes

- GitHub does not run workflows on PRs opened by GitHub Actions, so bot PRs (e.g. update-flake-lock) are exempt automatically; keep the `[bot]` guard as belt and braces.
- Without branch protection the failing check is visible but does not block merge; add `lint-prose` to required status checks to hard-block.
- ubuntu-latest runners preinstall python3 and gh.
