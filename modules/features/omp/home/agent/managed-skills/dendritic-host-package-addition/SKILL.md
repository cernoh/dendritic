---
name: dendritic-host-package-addition
description: "Add one package to a single dendritic host (NIXPC/ASAHI) and prove it lands: placement decision (host file vs shared desktop bundle vs new feature module), the parse/nixfmt/toplevel-eval gates, and the behavioral proof from the evaluated environment.systemPackages and the resolved store bin/ listing."
---

# Adding one package to a single dendritic host

Use when the request is "add package X to host H" and no daemon, service, or
per-user config is involved. Verified 2026-09-20 on `cernoh/dendritic` for
`transmission_4-qt` on NIXPC (issue #236, PR #237).

## Placement decision (do this first)

| Scope | Destination |
| --- | --- |
| One host only | that host's host file, e.g. `modules/hosts/NIXPC/nixpcConfiguration.nix` (`environment.systemPackages` already exists there with `btrfs-progs`) |
| Both hosts, plain CLI tool | `modules/attrs/desktop/default.nix` shared list |
| Needs options, services, out-of-store config, or HM programs | new `modules/features/<name>/` module, then add `self.nixosModules.<name>` to the host's `modules` list |

Do NOT reach for a feature module for a bare package. A feature module for one
binary is weight with no contract. If the user links upstream NixOS wiki docs
that describe `services.<x>`, still ship only what they asked for and offer the
service as a follow-up.

Host file edits need no `imports` change, so the diff is one list entry plus a
comment naming the host scope.

## Gates (cheap to expensive)

```bash
cd .worktrees/<branch>            # never the dirty main checkout
nix-instantiate --parse modules/hosts/NIXPC/nixpcConfiguration.nix

FMT=$(nix eval --impure --raw --expr \
  'let f = builtins.getFlake "/home/davr/.config/dendritic"; in f.inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt')
"$FMT/bin/nixfmt" --check modules/hosts/NIXPC/nixpcConfiguration.nix

nix eval --impure --raw .#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath
```

The NIXPC toplevel eval is fast here (~30 s warm) despite the full nixpkgs +
home-manager tree; run it in the foreground. `evaluation warning: The option
'programs.noctalia-greeter' … has been renamed` is pre-existing noise.

## Behavioral proof (the part that actually shows the package landed)

A successful eval only proves the file parses as a module. Two more checks tie
the request to an artifact:

```bash
# 1. the evaluated system list carries the package
nix eval --impure --json .#nixosConfigurations.NIXPC.config.environment.systemPackages \
  --apply 'ps: map (p: p.pname or p.name) ps'

# 2. the resolved output really ships the binary the user will run
OUT=$(nix build --no-link --print-out-paths --impure --expr \
  'let f = builtins.getFlake "/home/davr/.config/dendritic"; in
   f.inputs.nixpkgs.legacyPackages.x86_64-linux.<attr>')
ls "$OUT/bin"
```

Trap: `pname` for `transmission_4-qt` is `transmission`, so a name grep must be
case-insensitive on the attribute you intended, not on the pname string. The
`bin/` listing is the claim the user cares about.

`nix build` of a common package resolves from cache in seconds.

## Ship loop

Issue first via the `issue-scribe` agent → `git worktree add .worktrees/feat-<N>-<name> -b feat/<N>-<name> origin/main` → edit → gates → commit → push → PR
(`Closes #N`) → `gh pr edit <n> --title "<title> (#<n>)"` → watch the
`STE writing` / `Nix CI` / `Nix quality` runs to success → `git worktree remove`
and keep the branch until merge.

Related skills: `dendritic-feature-change-verification` (full gates + STE lint
recipe), `dendritic-stacked-prs-and-worktrees` (base-chain PRs, `gh stack`
failures), `omp-worktree`.
