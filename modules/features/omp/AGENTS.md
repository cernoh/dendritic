# omp — Oh My Pi feature

## Purpose
Dendritic integration for `can1357/oh-my-pi` via prebuilt GitHub release binaries (not a flake build). Exposes `overlays.omp`, `packages.omp`, `flake.nixosModules.omp` / `flake.homeManagerModules.omp` (plus `oh-my-pi` compat aliases), and wraps the HM module with out-of-store `~/.omp` symlink and declarative non-secret settings. The store package is pinned; activation fetches `releases/latest`. Ships two managed skills (`show-html`, `grilling`) and one extension (`html-report`, which registers the `render_html` tool).

## Ownership
- `default.nix` — overlay + NixOS/HM modules (binary package, settings, symlink, MCP, latest-binary, theme, and HTML-theme activations)
- `_omp.pkg.nix` — prebuilt binary, strictly pinned (`fetchurl` + per-system SRI hash); pristine binary + glibc-loader wrapper on Linux, never patchelf'd
- `home/` — tracked omp config: `agent/` (RULES.md, managed-skills/, extensions/, plugins/, prompts), out-of-store target for `~/.omp`
- `home/agent/managed-skills/` — versioned managed skills, each a `<name>/SKILL.md`; a skill may bundle extra files, for example `jj-guide/references/*.md`, or a vendored pack such as `show-html/assets/*.html`
- `home/agent/extensions/` — extension modules that omp discovers and loads in every session: `html-report.ts` (the `render_html` tool), `grill-form.ts` (the `grill_form` and `grill_finish` tools plus the loopback submit bridge), and `lib/` (the shared page shell, palette, and HTML environment folder; a subdirectory without `index.ts` is not loaded as an extension)
- `home/agent/scripts/` — helper scripts the skills call, for example `ste-lint.py`
- `home/plugins/` — `omp-plugins.lock.json`, `bun.lock`, `package.json` (Bun plugin set)

## Local Contracts
- **Binary, not source-built:** `flake.overlays.omp` and `perSystem.packages.omp` are `https://github.com/can1357/oh-my-pi/releases/download/v<pinnedVersion>/omp-*`, fetched with `fetchurl` and a per-system SRI hash. Linux uses the **glibc** assets (`omp-linux-x64` / `omp-linux-arm64`) — NOT the `omp-linux-musl-*` assets, which are dynamically musl-linked (`/lib/ld-musl-*`, `libc.musl-*.so.1`), not static, so they are no more portable on NixOS. No `inputs.oh-my-pi` flake input.
- **The package must stay pure.** `programs.omp.package` lands in `home.packages`, and Home Manager's `.manpath` builds a `buildEnv` over those packages, so an unhashed fetch in this package breaks every pure host eval (issue #173). Currency therefore comes from activation, not from evaluation.
- **Pristine binary + loader wrapper, never patchelf:** the Linux binary is a Bun single-file executable — rewriting INTERP/RPATH with patchelf corrupts its embedded payload lookup and it segfaults at startup (verified 2026-09-07: patchelf'd copy SIGSEGVs on `ldd`/`--version`, pristine copy runs clean under the Nix loader). So `_omp.pkg.nix` installs the untouched download as `$out/share/omp/omp.bin` plus a `$out/bin/omp` wrapper exec'ing it through `stdenv.cc.bintools.dynamicLinker --library-path …` (NixOS has no `/lib`). Both activation scripts (HM `~/.local/bin/omp` + `omp.bin`, NixOS `/usr/local/bin/omp` + `omp.bin`) do the same after download. Never patchelf this binary back.
- **Currency is an activation fetch:** `programs.omp.useLatestBinary = true` (default) `curl`s `releases/latest` to `~/.local/bin/omp` + `omp.bin` (HM) / `/usr/local/bin/omp` + `omp.bin` (NixOS) on each activation, so the binary stays current without a rebuild. Set it false to pin the machine to the store package.
- **Out-of-store `~/.omp`:** HM module symlinks `~/.omp` to `features/omp/home` in this checkout. Runtime state (dbs, sessions, logs) is written live into the checkout; only tracked config is committed.
- **Global agent rules:** `home/agent/RULES.md` is loaded into every omp session (branch/PR workflow, structured JSON output, new-project DOX bootstrap). Live via the out-of-store link; keep it generic — it applies to every repo, not just dendritic.
- **Compat alias:** `flake.homeManagerModules.oh-my-pi` and `flake.nixosModules.oh-my-pi` mirror `omp` for existing local imports; `programs.oh-my-pi` maps to `programs.omp`.
- **No secrets in Nix:** `programs.omp.settings` / `home.activation.ompMcp` carry only non-secret settings. API keys via env/sops/credential store.
- **Pinned release:** `_omp.pkg.nix` carries `pinnedVersion` + one SRI hash per system, and nothing else. There is no impure evaluation path.
- **Extensions load from `home/agent/extensions/`:** omp scans `~/.omp/agent/extensions/*.ts` through its native discovery, so a new module needs the file and the `!agent/extensions/` re-include in `home/.gitignore`, and no `extensions:` setting. A module may import Node builtins; it runs inside the omp process for every session, so keep it free of timers and global state.
- **`render_html` escapes every source byte:** the output is one file with inline CSS and script and no network dependency, and raw HTML in the source renders as text. Default output is `<agent dir>/html/`, where the agent dir is `PI_CODING_AGENT_DIR` or `~/.omp/agent`; `agent/*` already ignores that path.
- **The report palette comes from `self.scheme`:** `home.activation.ompHtmlTheme` writes `~/.omp/agent/html-theme.json` from `self.scheme.html`, and `lib/html.ts` reads it for the desktop theme. Every page keeps light and dark built in, so it still reads when that file is absent.
- **The grill form bridges the browser to the session:** `grill_form` starts a loopback HTTP server on an ephemeral port and serves one page per round. A submit writes `data/answers-<n>.json` and calls `pi.sendUserMessage`, so the answers arrive as the next user message. Every route needs the per-process token, the handle is unref'd, and `session_shutdown` closes it.
- **The HTML environment is a temp folder:** `<tmpdir>/omp-html-env-*` holds `data/` (rounds and answers), `public/` (pages), `flake.nix` (dev shell with Node and Bun), and `README.md`. It is created on first use and never lives in a repository.
- **The HTML tools register `loadMode: "essential"`:** omp otherwise treats an extension tool as discoverable and the model reaches it through the `xd://<tool>` device bridge rather than a direct call.
- **Vendored skill packs carry provenance:** a vendored skill keeps `UPSTREAM.md` (source, commit, licence, list of local edits) and the upstream licence text. Leave vendored files unedited.

## Work Guidance
- Bump the pinned release by hand: read `SHA256SUMS.txt` from the new release, convert the four hex digests to SRI, update `pinnedVersion` + `pinnedSources` in `_omp.pkg.nix`, then build and run one asset to prove it.
- Upstream asset linkage may change; the wrapper needs no linkage probing. Keep glibc asset names; musl assets are dynamically linked, not static.
- Pinned hashes are SRI (`sha256-<b64>`) converted from upstream `SHA256SUMS.txt` hex via `printf %s <hex> | xxd -r -p | base64`, confirmed by the `hash` field of `nix store prefetch-file --json <url>`.
- No heredocs in activation scripts: nixfmt reindents `''`-string bodies, which indents the terminator and breaks the script at activation time (2026-09-08: `WRAP_EOF` never matched). Write small files with single-line `printf '%s\n' …`. No literal `''` inside `''` strings either (it terminates the string). After editing, render the entry (`nix eval …home.activation.<name>.data --impure --raw`) and check it with `bash -n` — parse/eval alone do not catch shell breakage.
- Add/rename a skill: add directory under `home/agent/managed-skills/<name>/SKILL.md`; wire through `default.nix` if needed.
- Add an extension: write `home/agent/extensions/<name>.ts`; no flake edit and no `extensions:` setting are needed. Prove it in a fresh session before you commit.
- Share code between extensions: put it under `home/agent/extensions/lib/` and import it with a relative path. Only direct `*.ts` files under `extensions/` load as extensions, so a subdirectory without `index.ts` stays a plain module.
- Vendor a skill pack: pin the upstream commit, copy the files unchanged, and record the commit, the licence, and every local edit in `UPSTREAM.md`.
- Skill URIs resolve as `skill://<name>` for `SKILL.md` and `skill://<name>/<path>` for bundled files (verified 2026-09-13: `skill://jj-guide/references/workflows.md` returns `# jj Workflows`). Use those URIs in skill cross-references, not relative markdown paths.
- OMP discovers skills once, at session start. A running session does not list a new skill until restart. `omp read skill://<name>` is not a discovery check — it answers `Unknown skill` for every skill, including installed ones. Start a fresh session (`omp -p …`) to confirm discovery.
- `@sinamtz/pi-minimax-provider` stays disabled (`enabled: false` in `home/plugins/omp-plugins.lock.json`): it registers a custom `streamSimple` under the builtin `anthropic-messages` API, which omp ≥18.x rejects at startup (`Cannot register custom API ... built-in API names are reserved`, still present in 1.1.7). Re-enable only after upstream fixes it; for MiniMax models use a declarative `models.yml` provider (`baseUrl: https://api.minimax.io/anthropic`, `api: anthropic-messages`) instead.
- Keep `home/` focused on tracked config; runtime artifacts (`.db`, `sessions/`, `logs/`) are gitignored via `home/.gitignore`.

## Verification
- `nix-instantiate --parse modules/features/omp/default.nix`
- `nix-instantiate --parse modules/features/omp/_omp.pkg.nix`
- Purity gate (must pass with no `--impure`): `nix eval --accept-flake-config --raw '.#packages.x86_64-linux.omp.drvPath'`
- `nix build .#omp` then `<out>/bin/omp --version` — proves the pinned asset is real and runs
- `omp -p --no-session --no-title --model @smol "…"` — a fresh session that lists the skills, or that calls `render_html` and reports the output path. Skill discovery happens at session start, so this is the only real discovery check.
- `nix eval --impure --raw .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.activation.ompHtmlTheme.data` — the HTML theme file that activation writes.
- A `-p` run exits after one turn, so it cannot prove the form bridge. Drive a live session over RPC instead: `omp --mode rpc --no-session --auto-approve --model @smol`, send `{"type":"prompt","message":"…"}`, read the form URL off stdout, POST the answers to `<url>/answers`, and confirm the answers arrive as the next user message. Wait for `get_state` → `isStreaming: false` before the next prompt, or the prompt is rejected with "Agent is already processing".
- `nix flake check --impure`
