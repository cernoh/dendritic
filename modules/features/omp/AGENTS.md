# omp — Oh My Pi feature

## Purpose
Dendritic integration for `can1357/oh-my-pi` via prebuilt GitHub release binaries (not a flake build). Exposes `overlays.omp`, `packages.omp`, `flake.nixosModules.omp` / `flake.homeManagerModules.omp` (plus `oh-my-pi` compat aliases), and wraps the HM module with out-of-store `~/.omp` symlink and declarative non-secret settings. Auto-updates to `releases/latest` by default (`--impure`).

## Ownership
- `default.nix` — overlay + NixOS/HM modules (binary package, settings, symlink, MCP, latest-binary activation)
- `_omp.pkg.nix` — prebuilt binary (`fetchurl` per-system, `autoUpdate = true` via `builtins.fetchurl` without hash; pinned fallback with `autoUpdate = false`; pristine binary + glibc-loader wrapper on Linux, never patchelf'd)
- `home/` — tracked omp config: `agent/` (RULES.md, managed-skills/, plugins/, prompts), out-of-store target for `~/.omp`
- `home/agent/managed-skills/` — 18 versioned skills each with `SKILL.md`
- `home/agent/plugins/` — `omp-plugins.lock.json`, `bun.lock`, `package.json` (Bun plugin set)

## Local Contracts
- **Binary, not source-built:** `flake.overlays.omp` and `perSystem.packages.omp` are `https://github.com/can1357/oh-my-pi/releases/latest/download/omp-*` fetched impurely via `builtins.fetchurl` (no hash). Linux uses the **glibc** assets (`omp-linux-x64` / `omp-linux-arm64`) — NOT the `omp-linux-musl-*` assets, which are dynamically musl-linked (`/lib/ld-musl-*`, `libc.musl-*.so.1`), not static, so they are no more portable on NixOS. No `inputs.oh-my-pi` flake input.
- **Pristine binary + loader wrapper, never patchelf:** the Linux binary is a Bun single-file executable — rewriting INTERP/RPATH with patchelf corrupts its embedded payload lookup and it segfaults at startup (verified 2026-09-07: patchelf'd copy SIGSEGVs on `ldd`/`--version`, pristine copy runs clean under the Nix loader). So `_omp.pkg.nix` installs the untouched download as `$out/share/omp/omp.bin` plus a `$out/bin/omp` wrapper exec'ing it through `stdenv.cc.bintools.dynamicLinker --library-path …` (NixOS has no `/lib`). Both activation scripts (HM `~/.local/bin/omp` + `omp.bin`, NixOS `/usr/local/bin/omp` + `omp.bin`) do the same after download. Never patchelf this binary back.
- **Auto-update by default:** `_omp.pkg.nix:autoUpdate = true` resolves `version` from GitHub API and fetches latest binary impurely (requires `--impure`, which dendritic already uses). `programs.omp.useLatestBinary = true` also `curl`s latest to `~/.local/bin/omp` (HM) / `/usr/local/bin/omp` (NixOS) on each activation for instant update without rebuild.
- **Out-of-store `~/.omp`:** HM module symlinks `~/.omp` to `features/omp/home` in this checkout. Runtime state (dbs, sessions, logs) is written live into the checkout; only tracked config is committed.
- **Global agent rules:** `home/agent/RULES.md` is loaded into every omp session (branch/PR workflow, structured JSON output, new-project DOX bootstrap). Live via the out-of-store link; keep it generic — it applies to every repo, not just dendritic.
- **Compat alias:** `flake.homeManagerModules.oh-my-pi` and `flake.nixosModules.oh-my-pi` mirror `omp` for existing local imports; `programs.oh-my-pi` maps to `programs.omp`.
- **No secrets in Nix:** `programs.omp.settings` / `home.activation.ompMcp` carry only non-secret settings. API keys via env/sops/credential store.
- **Pinned fallback:** set `_omp.pkg.nix:autoUpdate = false` and `programs.omp.useLatestBinary = false` to use pinned `version` + SRI hashes (reproducible).

## Work Guidance
- Auto-update is default; no manual bump needed. To pin: set `pkgs.callPackage ./_omp.pkg.nix { autoUpdate = false; }` and `programs.omp.useLatestBinary = false`, then update `version` + per-system `hash` in `_omp.pkg.nix` (query `https://api.github.com/repos/can1357/oh-my-pi/releases/latest`, convert hex digests to SRI via `nix store prefetch-file <url>`).
- Upstream asset linkage may change; the wrapper needs no linkage probing. Keep glibc asset names; musl assets are dynamically linked, not static.
- Pinned hashes are SRI (`sha256-<b64>`) converted from upstream `SHA256SUMS.txt` hex via `echo <hex> | xxd -r -p | base64` (verify one with `nix hash file --sri <download>`).
- No heredocs in activation scripts: nixfmt reindents `''`-string bodies, which indents the terminator and breaks the script at activation time (2026-09-08: `WRAP_EOF` never matched). Write small files with single-line `printf '%s\n' …`. No literal `''` inside `''` strings either (it terminates the string). After editing, render the entry (`nix eval …home.activation.<name>.data --impure --raw`) and check it with `bash -n` — parse/eval alone do not catch shell breakage.
- Add/rename a skill: add directory under `home/agent/managed-skills/<name>/SKILL.md`; wire through `default.nix` if needed.
- Keep `home/` focused on tracked config; runtime artifacts (`.db`, `sessions/`, `logs/`) are gitignored via `home/.gitignore`.

## Verification
- `nix-instantiate --parse modules/features/omp/default.nix`
- `nix-instantiate --parse modules/features/omp/_omp.pkg.nix`
- `nix eval .#packages.aarch64-linux.omp.version --impure` / `nix build .#omp --impure` (impure latest)
- `nix flake check --impure`
