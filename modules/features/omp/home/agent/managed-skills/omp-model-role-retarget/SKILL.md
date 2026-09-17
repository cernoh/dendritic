---
name: omp-model-role-retarget
description: "Retarget OMP model roles to a different provider model in the dendritic flake: find the real model slug from live provider discovery, write it from both the declarative settings and the live config, and ship it as an issue-linked PR. Use when asked to change which model omp uses, when a provider released a newer model, or when refreshing the opencode-go model list."
---

# Retargeting OMP model roles

Verified 2026-09-10 on `cernoh/dendritic` (retarget `opencode-go` roles to DeepSeek V4.1, PR #151).

## 1. Resolve the real model slug, never guess it

Provider display names, ids, and selectors differ. `deepseek-v4.1-flash` is "DeepSeek V4.1 Flash"; the bare `deepseek-flash` id is a null-metadata stub — never use it.

```bash
omp models --json <provider> > /tmp/m.json     # fields: provider, id, selector, name
nu -c 'open /tmp/m.json | get models | where id =~ "deepseek" | select id name'
# or read the per-account discovery cache directly:
nu -c 'open ~/.omp/agent/models.db | get model_cache
       | where provider_id =~ "opencode-go"
       | select provider_id authoritative updated_at'
```

The authoritative rows come from live provider endpoint discovery, so a newly released model appears there before any local update. Bundled-catalog probes of the binary are unnecessary and easy to get wrong: `~/.local/bin/omp` is a 336-byte bash shim, the real Bun binary is `~/.local/bin/omp.bin`.

## 2. Check the bundled catalog is not the problem

`omp models` already merges discovery, so a model missing from a hand-maintained list is not a reason to add `models.yml`. A custom provider entry is only needed when the endpoint itself does not expose the model.

## 3. Write the change in two places

- Declarative source of truth: `modules/features/omp/default.nix`, `programs.omp.settings.modelRoles = { default; task; plan; slow; advisor; }`. Home Manager regenerates the file wholesale at activation: `home.activation.ompConfig` runs `cat > ~/.omp/agent/config.yml`.
- Live effect: `~/.omp/agent/config.yml` is the out-of-store target of `~/.omp`, so edit it in place to change the running install before the next switch.

`omp config set` needs the whole record as one JSON value. Dotted paths fail with `Unknown setting`:

```bash
omp config set modelRoles '{"default":"opencode-go/deepseek-v4.1-flash",
 "task":"opencode-go/deepseek-v4.1-flash","plan":"opencode-go/deepseek-v4.1-flash",
 "slow":"opencode-go/deepseek-v4.1-flash","advisor":"opencode-go/deepseek-v4.1-flash"}'
omp config get modelRoles
```

Never commit `config.yml`. The worktree copy usually carries unrelated live edits, and Home Manager overwrites it at activation anyway.

## 4. Verify

```bash
nix-instantiate --parse modules/features/omp/default.nix
FMT=$(nix eval --impure --raw --expr 'let f = builtins.getFlake "/home/davr/.config/dendritic"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style')
"$FMT/bin/nixfmt" --check modules/features/omp/default.nix
nix eval --impure --raw '.#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.activation.ompConfig.data'
nix eval --impure --raw '.#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath'
```

The activation-script eval is the cheapest proof: it prints the rendered YAML with the new selectors.

## 5. Ship it

Issue + branch + PR (`Closes #N`), per the repo workflow. Commit with an explicit pathspec, because the worktree often holds staged user files:

```bash
git add modules/features/omp/default.nix
git commit -- modules/features/omp/default.nix
```

Without `--`, a bare `git commit` picks up everything already staged.

`Evaluate NIXPC` / `Evaluate ASAHI` in Nix CI are green since #173 and are real gates. A red eval means your change; reproduce with `nix eval --accept-flake-config --raw '.#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath'`.

## 6. Refresh the OpenCode Go model list without retargeting

"Update the models listed under opencode go" is usually a data refresh, not a role change. Do it docs-first and keep the selectors.

Three evidence sources, each with one job:

- `https://opencode.ai/docs/go/` — canonical list, price/cap table, privacy table, and the **Endpoints** table.
- `omp models --json opencode-go` — the live account registry: id, name, context, max-out, thinking levels, vision, price. This is the only source for ids the docs page omits.
- `https://opencode.ai/data/` — usage ranking and author token share. It updates daily, so re-read it instead of trusting the numbers already in the skill. It spans all providers, so a top row may have no Go id.

Traps:

- The registry JSON has **no endpoint field**. Endpoint attribution (`/responses`, `/chat/completions`, `/messages`) comes from the docs Endpoints table only. Never infer it.
- The registry answers with more ids than the docs list. Split them in the skill: legacy ids, extra ids, and null-metadata stubs (`deepseek-flash`, and any id whose context and price are null). Stubs must carry a "never use" warning.
- `default.nix` carries **rank claims in comments** ("Rank #2 on opencode.ai/data"). Ranks flip. A pure ranking change leaves the selectors valid but makes those comments false, so grep for `Rank` when you refresh.
- Then check every selector in `modelRoles` and `retry.fallbackChains` against the registry. It drops unknown models silently.

Verify a docs-only refresh with `nix-instantiate --parse` plus `nixfmt --check`, then render the activation YAML from the worktree and from `main` and diff them: identical output proves nothing behavioural moved.

Lint the issue and PR prose before creating them (`skill://ste-lint-measurement-recipe`; use `nix shell nixpkgs#python3` when the host has no python). Refresh outcome 2026-09-16: PR #211, 39 registry ids against 29 docs models.
