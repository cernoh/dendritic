---
name: home-manager-ci-baseline
description: Use when designing GitHub Actions for this Home Manager flake repository.
---

## CI baseline

For this repository, inspect `flake.nix` as the source of truth. Validate the exposed configurations (`debian`, `nixwsl`, `nixpc`, `asahi`, and `darwin`) with evaluation/build-oriented checks rather than activation commands. The repository README documents `nix flake check` and `home-manager build --flake .#debian`.

The repository uses `nixfmt`/`nixfmt-rfc-style` convention. Do not add repository-wide formatter or linter gates without first fixing the existing baseline findings. Prefer changed-file-only quality checks for workflows, and validate workflow YAML with `actionlint`.

For changed-file diffs, `github.event.before` is not set on pull_request events. Use `origin/${{ github.event.repository.default_branch }}` for pull requests, `github.event.before` for pushes, and handle the all-zero before SHA for new branches.
