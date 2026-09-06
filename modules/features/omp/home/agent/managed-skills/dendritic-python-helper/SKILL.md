---
name: dendritic-python-helper
description: Add stdlib-only Python helper to dendritic flake via writePython3Bin with verification
---

# Dendritic Python Helper via writePython3Bin

Add a stdlib-only Python CLI to the dendritic flake (`~/.config/dendritic`) with zero new runtime deps.

## Layout
- Source: `modules/features/<area>/_<name>.py` (`_` prefix = skipped by import-tree, read via `builtins.readFile`).
- Package: `pkgs.writers.writePython3Bin "<bin-name>" {} (builtins.readFile ./_<name>.py)` in `home.packages` of the owning HM module.
- Docstring at top explains owner, caller (Lua/shell), and why no new deps.

## Constraints
- Stdlib only (`argparse`, `sqlite3`, `pathlib`, `shutil`, `tempfile`, `sys`). No third-party imports.
- `writePython3Bin` runs flake8 checks: keep lines ≤79 chars (E501 fails the nix build). Wrap f-strings via temp locals.
- Chromium cookie DBs: check `Default/Network/Cookies` first, then `Default/Cookies`. Copy DB + `-wal`/`-shm`/`-journal` sidecars to temp before read (live DB is locked).
- CLI shape: `<bin> <command> --profile-dir <path>`; exit 0 + value on stdout on success, exit 1 when absent.

## Verification (in order)
1. `nix-instantiate --parse modules/features/<area>/default.nix`
2. `<nix-python> -m py_compile modules/features/<area>/_<name>.py` (use `/nix/store/*-python3-*/bin/python3*`)
3. Functional test with fake SQLite DB: positive (both cookies present) + negative (empty profile → rc 1).
4. `nix-build -E 'with import <nixpkgs> {}; writers.writePython3Bin "<bin>" {} (builtins.readFile /home/davr/.config/dendritic/modules/features/<area>/_<name>.py)' --no-out-link` — catches flake8 E501.
5. End-to-end on packaged `$out/bin/<bin> extract --profile-dir <fake-profile>`.
6. `rm -rf modules/features/<area>/__pycache__/` (py_compile artifact must not ship).
7. `git add` new files FIRST — flake eval uses git-tracked sources, untracked `.py` = `path ... does not exist` error.
8. Host eval: `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.packages --impure --apply 'builtins.map (p: p.name or "none")' | grep <bin>`
9. `nixfmt --check modules/features/<area>/default.nix`

## Gotchas
- `nix log <drv>` shows the exact flake8 line on failure.
- `git status --short` dirty `config.yml` (omp agent) is pre-existing noise; leave it unless your task owns it.
- Branch/PR rules still apply: feature branch, `Closes #N`, PR title tag `(#N)`.
