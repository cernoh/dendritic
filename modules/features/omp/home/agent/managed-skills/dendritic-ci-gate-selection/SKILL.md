---
name: dendritic-ci-gate-selection
description: "Decide which GitHub Actions gates a cernoh/dendritic PR diff actually owes, and read their status without guessing: ci.yml and quality.yml are path-filtered to Nix paths, flow the STE gate only for prose, and branch-level run inspection via gh run list"
---

# Which CI gates a dendritic diff owes

Apply when a PR against `cernoh/dendritic` shows fewer checks than expected, or
before merging when a check appears "missing". Verified 2026-09-17 against
`main` at `f99fe43`.

## Path filters decide the check set

`.github/workflows/ci.yml` ("Nix CI") and `.github/workflows/quality.yml`
("Nix quality") both declare:

```yaml
on:
  pull_request:
    paths:
      - '**/*.nix'
      - 'flake.lock'
      - '.github/workflows/**'
```

So a diff touching only `README.md`, `AGENTS.md`, `.gitignore`, or
`modules/**/compose.yaml` owes **only** the STE gate
(`.github/workflows/ste-write.yml`, no path filter). "Evaluate NIXPC",
"Evaluate ASAHI", "Flake check", and "Format Nix (changed files)" will not
appear, and their absence is by design - do not force them with an empty
commit.

- Nix diff → 5 checks: `Evaluate NIXPC`, `Evaluate ASAHI`, `Flake check`,
  `Format Nix (changed files)`, `Lint prose`.
- Prose/docs/gitignore-only diff → 1 check: `Lint prose`.
- The `Evaluate <HOST>` jobs are the purity gate (pure `nix eval`, no
  `--impure`); `Flake check` runs `nix flake check --impure`.

## Read the status correctly

```bash
gh pr checks <N> --repo cernoh/dendritic          # per-gate state
gh run list --repo cernoh/dendritic --branch <branch> --limit 5
```

- `mergeStateStatus=UNSTABLE` means checks are pending **or** failing; it is
  not a verdict. Always name the failing gate with `gh pr checks` before
  merging.
- Editing the PR title (required: title ends `(#<N>)`) re-triggers
  `ste-write.yml`, which creates a **second run** and supersedes the first.
  Quote the newest run id when reporting.
- Local equivalents are cheaper than waiting: `nixfmt --check <files>` with the
  locked nixfmt binary, and STE via
  `nix shell nixpkgs#python3 --command sh -c 'python3 .github/scripts/ste-lint.py < /tmp/prose.txt'`.

## Trap

A `.gitignore` row that ignores a directory does **not** clear an
intent-to-add index entry for a file already inside it. In a colocated jj
checkout that entry surfaces as ` D <path>` and blocks the next `git pull`
with `Entry '<path>' not uptodate. Cannot merge.` + `fatal: stash failed`.
Clear it index-only:

```bash
git update-index --force-remove -- <path>
```

Never `git add` it (stages the artifact) and never `git stash` (fails on i-t-a
entries). See `skill://git-intent-to-add-pull-blocker`.
