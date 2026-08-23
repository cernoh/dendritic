---
name: nix-flake-debugging
description: "Diagnose Nix evaluation, build, activation, and dependency failures with minimal reproducible checks"
---

# Nix flake debugging

Use when a flake evaluates, builds, activates, or enters a dev shell incorrectly.

## Triage order
1. Classify the failure: parse/evaluation, dependency resolution, build, activation, runtime, or platform.
2. Capture the exact command and first meaningful error; do not hide it with `|| true`.
3. Reproduce from a clean checkout or explicit `--override-input` when possible.
4. Narrow the target: `nix eval`, `nix build`, `nix develop`, `home-manager build`, or `nixos-rebuild dry-build`.

## Safe diagnostics
```sh
nix flake check --show-trace
nix eval --show-trace .#<attribute>
nix build --show-trace .#<attribute>
nix develop --command bash -lc 'command -v <tool>; <tool> --version'
nix-store --verify --check-contents
```
Use `NIX_SHOW_STATS=1` only when evaluation cost matters. Avoid deleting the Nix store as a first response.

## Root-cause checks
- Confirm the target system matches `nixpkgs.system` and the host architecture.
- Inspect `flake show`, input follows, overlays, and package names before changing code.
- Check whether a path is a read-only store symlink before changing Home Manager activation.
- Separate evaluation errors from build failures; fix the earliest layer first.

## Verification
Add one focused assertion or runnable command for each fixed branch. Re-run the original failing command and the smallest relevant clean check. Report unresolved network, cache, hardware, or secret prerequisites explicitly.

## Renewal
Nix warning text and command flags evolve. Validate commands with `nix <command> --help` before preserving new diagnostics.
