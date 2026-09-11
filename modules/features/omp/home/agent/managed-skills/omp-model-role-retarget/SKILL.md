---
name: omp-model-role-retarget
description: "Retarget OMP model roles to a different provider model in the dendritic flake: find the real model slug from live provider discovery, write it from both the declarative settings and the live config, and ship it as an issue-linked PR. Use when asked to change which model omp uses, or when a provider released a newer model."
---

# Retargeting OMP model roles

Verified 2026-09-10 on `cernoh/dendritic` (retarget `opencode-go` roles to DeepSeek V4.1, PR #151).

## 1. Resolve the real model slug, never guess it

Provider display names, ids, and selectors differ. `deepseek-flash` is "DeepSeek V4.1 Flash"; there is no `deepseek-v4.1` id.

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
omp config set modelRoles '{"default":"opencode-go/deepseek-flash",
 "task":"opencode-go/deepseek-flash","plan":"opencode-go/deepseek-flash",
 "slow":"opencode-go/deepseek-flash","advisor":"opencode-go/deepseek-flash"}'
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

`Evaluate NIXPC` / `Evaluate ASAHI` in Nix CI fail on this repo for a pre-existing reason (`home.file.".manpath"` reaching the impure `builtins.fetchurl`). Confirm against older `main` runs before attributing it to the change.
