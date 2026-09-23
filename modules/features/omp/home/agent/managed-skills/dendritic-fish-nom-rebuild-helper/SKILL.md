---
name: dendritic-fish-nom-rebuild-helper
description: "Add or verify a fish helper in the dendritic flake that runs nixos-rebuild switch through nix-output-monitor (nom): the |& json pipe, $pipestatus, sudo priming, out-of-store symlink targeting the main checkout, and the stubbed function test"
---

Use when asked for a fish command in `cernoh/dendritic` that rebuilds NIXPC/ASAHI through nix-output-monitor, or when a nom-wrapped rebuild shows nothing.

Worked example: issue #243, PR #244 (`nom-switch`).

## The recipe that works

```fish
sudo -v
or return 1
sudo nixos-rebuild switch --impure --flake ".#$host" --log-format internal-json -v |& nom --json
set -l st $pipestatus[1]
```

Four details, each measured on this host (2026-09-21, nixos-rebuild-ng 26.11, nix 2.34.8, nom 2.2.0):

- **`|&` is load-bearing.** nix writes the internal-json log to stderr. `2>&1 |` and `|&` are equivalent in fish; a plain `|` gives nom nothing.
- **`$pipestatus[1]`, never `$status`.** The pipeline ends in nom, so `$status` is nom's status. Verified: `false |& cat` then `set -l s $pipestatus[1]` gives 1.
- **`sudo -v` before the pipeline.** nixos-rebuild-ng elevates only for activation, and the sudo prompt goes to stderr — the pipe captures it, so an unprimed run hangs with an invisible prompt.
- **`--log-format` reaches nix.** `nixos-rebuild-ng` accepts `--log-format` and `-v` in `common_flags`, folds them into `flake_build_flags` (`models.py:183-188`), and passes them to `nix build` (`nix.py:88`); `dict_to_flags` (`utils.py:23-41`) emits `--log-format internal-json` and `-v` for the `v` count. `internal-json` is still a valid nix 2.34 format.

Note: `nixos-rebuild` here is `nixos-rebuild-ng` (python). Not the old bash script.

## Host-name facts

- `networking.hostName` is `NIXPC` and `ASAHI`, matching the flake attribute names — but read the default from fish's own `$hostname` variable, not the `hostname` binary (no PATH dependency).
- The home-manager user name differs per host: `davr` on NIXPC, `da` on ASAHI. Resolve the checkout from `$HOME/.config/dendritic`, never a literal user path.
- Both hosts need `--impure` (`hardwareFromMachine` reads `/etc/nixos/hardware-configuration.nix`).

## Delivery fact that bites

`~/.config/fish/functions` resolves through `/nix/store/*-hm_functions` to the **main checkout** path `~/.config/dendritic/modules/features/fish/home/.config/fish/functions`. Work on a `feat/...` branch under `.worktrees/` is NOT live. A helper file only appears in the live dir after merge to main, and its packaged binaries (`nix-output-monitor`) only after a switch. So:

- Give the user a bootstrap one-liner for the window before merge, and
- Optionally fall back in the helper: `set -l monitor nom` then `type -q nom; or set monitor nix run 'nixpkgs#nix-output-monitor' --`, used as `|& $monitor --json`.

## Verification without root

`sudo` needs a password here, so verify the function with stubs. Put `sudo`, `nixos-rebuild`, `nom`, and `nix` shims in a temp dir, prepend it to `PATH`, and set `HOME` to a temp dir holding `.config/dendritic`.

Stub `sudo`: `if [ "$1" = "-v" ]; then exit 0; fi; exec "$@"` — **no `shift`**, or the stub eats the command name and the case fails with 127.

Stub `nixos-rebuild` appends `PWD` and `"$*"` to `$NS_LOG`, then exits `${NS_STATUS:-0}`.

Cases worth running: explicit host, no-argument default, non-zero status propagated (`$NS_STATUS=7`), `nom` absent (assert `nix run nixpkgs#nix-output-monitor -- --json`), missing checkout (status 1 with a clear error).

Prove the real pipe once against a real build, using the same flags nixos-rebuild forwards:

```fish
nix build --impure --no-link --print-out-paths --log-format internal-json -v \
  --expr 'let pkgs = import (builtins.getFlake "nixpkgs") {}; in pkgs.runCommand "nom-probe" {} "echo probe > $out"' \
  |& nix run nixpkgs#nix-output-monitor -- --json
```

Expect the dependency graph, then the out path. The `--print-build-logs` trap does not apply to this stream.

## Gates and CI

- `nix-instantiate --parse`, `fish --no-execute`, `nixfmt --check` with the **locked** nixfmt (get it with `getFlake` on the worktree path; the main checkout can fail to evaluate when an agent session left a `.nix` file under `modules/features/omp/home/agent/sessions/`, which import-tree then picks up).
- Eval `.#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath --impure` for both hosts.
- Prove the package lands: `... .config.home-manager.users.<user>.home.packages --apply 'ps: map (p: p.name) (builtins.filter (p: (p.pname or "") == "nix-output-monitor") ps)'`.
- `Flake check → verify-fmt` is already red on `main` (nvf files at HEAD, 2026-09-21). Check `git diff --name-only origin/main...origin/<branch>` before blaming your branch.
