---
name: nix-input-graphs
description: "Keep flake input follows, lock updates, and package-set identity correct and reviewable"
---

# Nix input graphs

Use when adding inputs, changing `follows`, or reviewing lock-file churn.

## Rules
- Treat `flake.lock` as generated state: update it with Nix, never hand-edit it.
- Decide whether an input should follow the root `nixpkgs` before adding a second nixpkgs revision.
- Avoid duplicate nixpkgs package sets unless the incompatibility is intentional and documented.
- Never hide input changes with `--no-write-lock-file` or leave an `--override-input` workaround undocumented.

## Procedure
1. Inspect the input graph with `nix flake metadata`.
2. Check existing `follows` declarations before adding an input.
3. Change only the requested input edge or URL.
4. Run `nix flake lock --update-input <name>` (or the repository's pinned command).
5. Review the lock diff for unrelated node churn and verify the affected output.

## Checks
A lock update can alter transitive nixpkgs, compiler, or module types. Re-run evaluation for every output that consumes the changed input.

## Renewal
Input graph conventions depend on current upstream flake contracts. Re-read the input's README/flake and current `nix flake lock --help` before preserving a new pattern.

Source: https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix3-flake.html
