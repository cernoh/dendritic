---
name: dojjo
description: Reference for working with jj workspaces via the Dojjo (djo) CLI in agent workflows.
---

# Dojjo quick reference

Dojjo is a workspace manager for [jj](https://github.com/jj-vcs/jj) — worktrunk for jj. It manages `jj workspace` lifecycle (create, switch, merge, remove), runs hooks at each stage, and keeps worktrunk-compatible config.

In this repo `dojjo` is packaged as `perSystem.packages.dojjo` (`djo` + `dojjo` aliases, completions for bash/zsh/fish) and exposed as `flake.homeManagerModules.dojjo` / `flake.nixosModules.dojjo`. It is also included in `self.nixosModules.programming` (system programming bundle, alongside `lazygit`).

## Core commands

All commands run from within a jj repository (colocated or not).

- `djo switch [<name>]` — Create (if needed) and switch to workspace + bookmark. Use `djo switch -` for previous, `djo switch ^` for default.
- `djo list` — List workspaces with status: `*` current, `✘` conflicts, `↕` divergent.
- `djo merge [<target>]` — Squash, rebase onto target, move bookmark, forget workspace, delete directory, optionally push. Defaults to default branch. On failure: `jj op undo`.
- `djo remove [<branch>]` — Remove workspace + bookmark.
- `djo for-each -- <cmd>` — Run command in every workspace.
- `djo prune` — Remove workspaces whose bookmarks are merged into trunk.
- `djo copy-ignored` — Copy build caches from another workspace.
- `djo update-stale` — Fix stale working copies.
- `djo hook <type>` — Manually run hooks.
- `djo config show` — Show effective config.
- `djo shell` — Shell integration.
- `djo run <alias>` — Run a configured alias.

## List output

`djo list` shows each workspace: bookmarks in `[]`, indicators `*`/`✘`/`↕`, and description.

## Shell integration (opt-in)

```bash
eval "$(djo shell init zsh)"    # zsh
eval "$(djo shell init bash)"   # bash
djo shell init fish | source    # fish
```

Completions installed to `share/bash-completion`, `share/zsh/site-functions`, `share/fish` via `postInstall` (`djo shell completion …`).

## Configuration

TOML configs, merged low→high: `~/.config/worktrunk/config.toml` → `.config/wt.toml` → `~/.config/dojjo/config.toml` → `dojjo.toml` → `dojjo.local.toml`.

```toml
workspace-path = "{{ repo_path }}/../{{ name }}"
create-bookmark = true
[merge]
squash = true
rebase = true
remove = true
verify = true
push = false
```

`djo config show` to verify. Templates use Jinja2: `{{ name | sanitize }}`, `{{ name | hash_port }}` etc.

## Agent workflow

```bash
djo switch my-feature
djo list
jj log
djo copy-ignored
djo merge
```

Parallel: `djo switch feat-a -- 'Implement feature A'`

## Nix integration

- `perSystem.packages.dojjo` — `buildDartApplication` from `inputs.dojjo` (`cli/` subdir), `pubspec.lock` vendored.
- `flake.homeManagerModules.dojjo` / `flake.nixosModules.dojjo` via `moduleWithSystem` (`self'.packages.dojjo`).
- System bundle: `self.nixosModules.programming` includes `dojjo`.
- Requires `jujutsu` (`jj`) — via `features/programming` or `pkgs.jujutsu`.
