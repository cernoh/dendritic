# omp — Oh My Pi feature

## Purpose
Dendritic integration for the `can1357/oh-my-pi` flake. Re-exports upstream as `overlays.omp`, `packages.omp`, `flake.nixosModules.omp` / `flake.homeManagerModules.omp` (plus `oh-my-pi` compat aliases), and wraps the HM module with out-of-store `~/.omp` symlink and declarative non-secret settings.

## Ownership
- `default.nix` — overlay re-export + HM/NixOS module wrapping (upstream `inputs.oh-my-pi`).
- `home/` — tracked omp config: `agent/` (RULES.md, managed-skills/, plugins/, prompts), `AGENTS.md` equivalent, out-of-store target for `~/.omp`.
- `home/agent/managed-skills/` — 18 versioned skills (git-prefixed, e.g. `dendritic-*`, `stremio-*`, `omp-*`) each with `SKILL.md`.
- `home/agent/plugins/` — `omp-plugins.lock.json`, `bun.lock`, `package.json` (Bun plugin set).

## Local Contracts
- **Upstream is source-built:** `flake.overlays.omp = inputs.oh-my-pi.overlays.default` builds from Rust+Bun source, not a binary fetch.
- **Out-of-store `~/.omp`:** HM module symlinks `~/.omp` to `features/omp/home` in this checkout. Runtime state (dbs, sessions, logs) is written live into the checkout; only tracked config is committed.
- **Compat alias:** `flake.homeManagerModules.oh-my-pi` and `flake.nixosModules.oh-my-pi` mirror `omp` for existing local imports.
- **No secrets in Nix:** `programs.omp.settings` / `home.activation.ompMcp` carry only non-secret settings (from `home/agent/config.yml`, `home/agent/mcp.json`). API keys via env/sops/credential store.
- **Managed skills:** `home/agent/managed-skills/<skill>/SKILL.md` — dendritic-managed, updated via overlay/package rev. Do not hand-edit generated skill wiring; edit the feature's Nix to change which skills are exposed.
- **Plugins:** `home/agent/plugins/` — Bun workspace; `omp-plugins.lock.json` pins versions.

## Work Guidance
- Bump omp: update `inputs.oh-my-pi` rev in `flake.nix` / `flake.lock`; verify `nix flake check --impure`.
- Add/rename a skill: add directory under `home/agent/managed-skills/<name>/SKILL.md`; wire through `default.nix` if the HM module needs to expose it.
- Keep `home/` focused on tracked config; runtime artifacts (`.db`, `sessions/`, `logs/`) are gitignored via `home/.gitignore`.

## Verification
- `nix-instantiate --parse modules/features/omp/default.nix`
- `nix eval .#overlays.omp --impure` / `nix build .#omp --impure` (per-system package)
- `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.<user>.programs.omp --impure`
- `nix flake check --impure` — upstream checks flow through `perSystem` re-exports.
