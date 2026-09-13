# .github — CI and automation

## Purpose
GitHub Actions workflows, issue/PR templates, and lint scripts for this flake. Runs outside the Nix sandbox (uses `nix run .#verify` impure path where needed).

## Ownership
- `workflows/ste-write.yml` — STE (Simplified Technical English) prose lint on PR/issue title+body; posts/updates `<!-- ste-lint -->` comment; fails check on violations; skips `*[bot]` authors.
- `workflows/` — additional CI: changed-file `nixfmt` check, eval matrix over `NIXPC` + `ASAHI`, weekly `flake.lock` bump (see `README.md:CI`).
- `scripts/ste-lint.py` — STE linter invoked by `ste-write.yml` (also runnable locally: `python3 .github/scripts/ste-lint.py < draft.md`).
- `ISSUE_TEMPLATE/issue.yml`, `pull_request_template.md` — contributor templates.

## Local Contracts
- **Prose gate is STE:** `ste-write.yml` concatenates `title + body` into `prose.txt`, runs `ste-lint.py → report.json`, and enforces `total == 0`. Signal is `::error::STE violations: N`.
- **Bot PRs are exempt:** author `*[bot]` short-circuits the job (update-flake-lock bot cannot rewrite its own body; GitHub Actions don't run on action-opened PRs anyway).
- **Comment lifecycle:** workflow upserts a `<!-- ste-lint -->` comment on failure, deletes it on pass — keeps one comment per PR/issue.
- **Nix CI has two jobs with different purity:** `Evaluate <HOST>` runs a *pure* `nix eval` of the host toplevel and is the purity gate — no `--impure`. `Flake check` runs `nix flake check --impure` and is the sandboxed ladder gate. `nix run .#verify` is the same ladder on the native machine, where impure hardware is visible.

## Work Guidance
- Test STE locally before pushing: `python3 .github/scripts/ste-lint.py < your-draft.md` and fix `violations` before opening PR.
- New workflow: place under `workflows/`; keep `nixConfig` caches in mind for `nix` steps (use `DeterminateSystems/nix-installer-action` or similar if needed).
- Weekly lock bump: no manual action unless CI signals eval breakage after the bump.

## Verification
- `python3 .github/scripts/ste-lint.py < prose.txt` — local STE check (mirrors CI).
- `nix run .#verify` / `nix flake check --impure` — Nix gates (not GitHub-specific, but CI runs them).
- Dry-run workflow: `act -W .github/workflows/ste-write.yml` (via `features/act`, needs `docker`).
