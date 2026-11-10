# <name> — <one line: what it is>

## Purpose

<What the feature delivers and the one problem it solves. Name where it is
imported (a host, a bundle, or `modules/attrs/*`) — import IS enabling, so the
import list is the only switch there is.

A feature with no contracts of its own should not have this file: the parent
`../AGENTS.md` already covers it, and a copy of the parent's rules goes stale
the moment one of them changes. Keep only what is true here and nowhere else.>

## Ownership

- `default.nix` — the feature's modules.
- `_<name>.pkg.nix` — the derivation and the pinned input it reads.
- `home/` — live-editable config, symlinked out of store.

<Delete the lines that do not exist. Shared contracts — import = enable, `_`
data files, out-of-store symlinks, explicit PATH for user services, colors from
`self.scheme`, per-machine `dendritic.<name>` options — are owned by
`../AGENTS.md`. Restate one here only when this feature sharpens it.>

## Local Contracts

- **<Rule name>.** <The rule and the failure it prevents. Cite the upstream
  behaviour, the version, or the issue that forced it, so the next session can
  tell a stale rule from a current one.>

## Work Guidance

- `nix fmt` covers this file like any other module.
- <The one or two commands an agent needs before it edits this feature, and
  anything it must not do (a host it must not touch, a file the app rewrites at
  runtime).>

## Verification

```sh
nix-instantiate --parse modules/features/<name>/default.nix
nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.<path> --impure
```

<The user is `config.dendritic.userName`, `davr` on both hosts. Say what a green
result proves and what it does not: an eval proves the option path resolved, not
that the service starts.>

## Child DOX Index

None.
