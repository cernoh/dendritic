---
name: nixpc-fish-sweep-switch
description: Add or verify a Fish helper that runs the nixpc NixOS rebuild and Home Manager switch from the home-manager-v3 repository
---

# NixPC Fish sweep switch

Use this procedure when adding or repairing the project helper that applies both system and Home Manager changes for the nixpc host.

## Helper contract

Define a Fish function in `config/fish.nix` named `nixpc-switch` that:

1. Uses `$HOME/.config/home-manager-v3` as the repository path.
2. Fails clearly if the repository directory does not exist.
3. Uses `pushd` into the repository and restores the caller's directory with `popd`.
4. Runs `sudo nixos-rebuild switch --flake .#nixpc` first.
5. Stops and returns the rebuild status when the NixOS switch fails.
6. Runs `home-manager switch --flake .#nixpc -b backup` only after a successful NixOS switch.
7. Returns the Home Manager status.

Example body:

```fish
set -l repo "$HOME/.config/home-manager-v3"
if not test -d "$repo"
  echo "Repository not found: $repo" >&2
  return 1
end

pushd "$repo" >/dev/null
or return 1

sudo nixos-rebuild switch --flake .#nixpc
set -l rebuild_status $status
if test $rebuild_status -ne 0
  popd >/dev/null
  return $rebuild_status
end

home-manager switch --flake .#nixpc -b backup
set -l switch_status $status
popd >/dev/null
return $switch_status
```

## Verification

Run:

```bash
nix-instantiate --parse config/fish.nix
nix eval --raw --impure --expr 'let f = builtins.getFlake (toString ./.); in "function nixpc-switch\n" + f.homeConfigurations.nixpc.config.programs.fish.functions."nixpc-switch".body + "\nend\n"' | fish --no-execute
nix flake check --no-build --show-trace
```

Commit only the Fish configuration change when working on this helper; preserve unrelated dirty files.
