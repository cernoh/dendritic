---
name: dendritic-feature-change-verification
description: "Verify a feature-module change in the ~/.config/dendritic master flake (or any NixOS flake): stage new .nix files before flake eval (untracked files are invisible to flake source copies), format via the locked nixpkgs nixfmt (the flake's .#formatter is broken), parse, targeted NIXPC eval gates, and STE-lint issue/PR drafts without a system python."
---

# Verifying feature-module changes in ~/.config/dendritic

Apply when adding/editing a feature under `modules/features/<name>/` and when
drafting the linked GitHub issue/PR. Verified against cernoh/dendritic, 2026-09.

## Facts that cost real time (do not rediscover)

1. **Untracked files are invisible to flake source copies.** `nix eval .#…` /
   `nix flake check` copy only *tracked* files (working-tree contents). A new
   `modules/features/sober/default.nix` that is not `git add`-ed produces
   `error: undefined variable 'sober'` at the `with self.nixosModules; [ … ]`
   import site of the *tracked* bundle file — the tracked edit IS in the copy,
   the new file is NOT. Fix: `git add` (or commit) the new file, then re-eval.
   Symptom asymmetry (`getFlake` path probe returning `true` while `.#` fails)
   is stale vs fresh source copies — do not chase it.
2. **Activation scripts run with a minimal PATH.** Locked nixpkgs
   `nixos/modules/system/activation/activation-script.nix` sets PATH to only
   coreutils, gnugrep, findutils, getent, libc, shadow, util-linux — NO
   systemPackages. Any other binary (e.g. flatpak) MUST be called by store
   path: `${pkgs.flatpak}/bin/flatpak`.
3. **`system.activationScripts.<name>` type is `attrsOf (either str
   (submodule { text; deps; }))`** (activation-script.nix ~line 126). A
   string definition merges to a plain string — `config.system.activationScripts.x`
   IS the text; do not append `.text` in evals.
4. **`nix run .#formatter` is broken** in this flake
   (`error: attribute 'formatter.type' does not exist`). CI checks fmt with
   the nixfmt binary directly; do the same (recipe below).
5. **STE linter needs python3**, absent from NixOS default PATH here — run it
   via `nix shell nixpkgs#python3`. The repo lints issue and PR titles+bodies
   (`.github/workflows/ste-write.yml`), so lint drafts BEFORE creating them.

## Verification ladder (cheapest first)

```bash
cd <worktree-or-checkout>          # never the dirty main checkout
# 1. parse
nix-instantiate --parse modules/features/<name>/default.nix
# 2. format — nixfmt binary from the LOCKED nixpkgs (match CI):
FMT=$(nix eval --impure --raw --expr \
  'let f = builtins.getFlake "…/dendritic"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style')
"$FMT/bin/nixfmt" modules/features/<name>/default.nix   # format in place
"$FMT/bin/nixfmt" --check modules/features/<name>/default.nix modules/attrs/<bundle>/default.nix
# 3. stage new files, THEN eval gates (see fact 1)
git add modules/features/<name>/default.nix
nix eval --impure --raw .#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath
# 4. proof of rendered activation script (fact 3: no .text suffix)
nix eval --impure --raw .#nixosConfigurations.NIXPC.config.system.activationScripts.<name>
```

NIXPC toplevel eval covers flatpak/portal assertions and module conflicts.
Prefers `--impure` on the native machine (hardware gate).

## STE-lint issue/PR drafts

```bash
# title + body on stdin; violations reported as JSON (total: 0 required)
printf '%s\n\n%s\n' "$TITLE" "$(cat /tmp/draft.md)" \
  | nix shell nixpkgs#python3 --command python3 .github/scripts/ste-lint.py
```

Rules that bite: no sentence >20 words, no semicolons, no em/en dashes, no
passive voice (`is set`, `be installed`), no banned/marketing words, no
paragraph >6 sentences. Blank-line-separate every bullet to keep paragraphs
short. `./`-paths in backticks are stripped only inside fenced code blocks.

## PR plumbing

- Generic rules apply: issue first (`gh issue create`), branch
  `feat/<N>-<name>` in `.worktrees/` (see omp-worktree skill), `Closes #N` in
  PR body, PR title ends `(#<prnum>)` (edit after create).
- Pre-existing failure to distinguish from yours: `nix flake check` fmt gate
  flags EVERY unformatted .nix file in the repo (`davinci`, `omp` were red at
  main HEAD). If your files pass `nixfmt --check` and both host eval jobs are
  green, the fmt failure is not your regression — report, do not reformat
  unrelated files.
