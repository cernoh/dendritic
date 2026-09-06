# omp — Oh My Pi feature

## Purpose
Dendritic integration for `can1357/oh-my-pi` via prebuilt GitHub release binaries (not a flake build). Exposes `overlays.omp`, `packages.omp`, `flake.nixosModules.omp` / `flake.homeManagerModules.omp` (plus `oh-my-pi` compat aliases), and wraps the HM module with out-of-store `~/.omp` symlink and declarative non-secret settings. Auto-updates to `releases/latest` by default (`--impure`).

## Ownership
- `default.nix` — overlay + NixOS/HM modules (binary package, settings, symlink, MCP, latest-binary activation)
- `_omp.pkg.nix` — prebuilt binary (`fetchurl` per-system, `autoUpdate = true` via `builtins.fetchurl` without hash; pinned fallback with `autoUpdate = false`)
- `home/` — tracked omp config: `agent/` (RULES.md, managed-skills/, plugins/, prompts), out-of-store target for `~/.omp`
- `home/agent/managed-skills/` — 18 versioned skills each with `SKILL.md`
- `home/agent/plugins/` — `omp-plugins.lock.json`, `bun.lock`, `package.json` (Bun plugin set)

## Local Contracts
- **Binary, not source-built:** `flake.overlays.omp` and `perSystem.packages.omp` are `https://github.com/can1357/oh-my-pi/releases/latest/download/omp-*` (musl static on Linux) fetched impurely via `builtins.fetchurl` (no hash). No `inputs.oh-my-pi` flake input.
- **Auto-update by default:** `_omp.pkg.nix:autoUpdate = true` resolves `version` from GitHub API and fetches latest binary impurely (requires `--impure`, which dendritic already uses). `programs.omp.useLatestBinary = true` also `curl`s latest to `~/.local/bin/omp` (HM) / `/usr/local/bin/omp` (NixOS) on each activation for instant update without rebuild.
- **Out-of-store `~/.omp`:** HM module symlinks `~/.omp` to `features/omp/home` in this checkout. Runtime state (dbs, sessions, logs) is written live into the checkout; only tracked config is committed.
- **Compat alias:** `flake.homeManagerModules.oh-my-pi` and `flake.nixosModules.oh-my-pi` mirror `omp` for existing local imports; `programs.oh-my-pi` maps to `programs.omp`.
- **No secrets in Nix:** `programs.omp.settings` / `home.activation.ompMcp` carry only non-secret settings. API keys via env/sops/credential store.
- **Pinned fallback:** set `_omp.pkg.nix:autoUpdate = false` and `programs.omp.useLatestBinary = false` to use pinned `version` + SRI hashes (reproducible).

## Work Guidance
- Auto-update is default; no manual bump needed. To pin: set `pkgs.callPackage ./_omp.pkg.nix { autoUpdate = false; }` and `programs.omp.useLatestBinary = false`, then update `version` + per-system `hash` in `_omp.pkg.nix` (query `https://api.github.com/repos/can1357/oh-my-pi/releases/latest`, convert hex digests to SRI via `nix store prefetch-file <url>`).
- Add/rename a skill: add directory under `home/agent/managed-skills/<name>/SKILL.md`; wire through `default.nix` if needed.
- Keep `home/` focused on tracked config; runtime artifacts (`.db`, `sessions/`, `logs/`) are gitignored via `home/.gitignore`.

## Verification
- `nix-instantiate --parse modules/features/omp/default.nix`
- `nix-instantiate --parse modules/features/omp/_omp.pkg.nix`
- `nix eval .#packages.aarch64-linux.omp.version --impure` / `nix build .#omp --impure` (impure latest)
- `nix flake check --impure`
