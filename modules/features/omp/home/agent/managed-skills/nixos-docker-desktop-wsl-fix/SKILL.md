---
name: nixos-docker-desktop-wsl-fix
description: Fix Docker Desktop WSL integration on NixOS when home-manager creates read-only config symlinks
---

# Docker Desktop on NixOS WSL

## Problem
Docker Desktop (Windows) tries to write to `~/.docker/config.json` via `wsl.exe -d <distro> -e sh -c cat - > ~/.docker/config.json`. On NixOS, if home-manager manages this file via `home.file`, it becomes a symlink to the read-only nix store → write fails with "Read-only file system".

## Symptom
```
failed to write file: running wslexec: ... Read-only file system
```

## Root Cause
`home.file.".docker/config.json"` creates a symlink:
```
~/.docker/config.json → /nix/store/.../home-manager-files/.docker/config.json
```
The nix store is read-only. Docker Desktop can't overwrite it.

## Fix
Replace the `home.file` entry with an activation script:

```nix
# Remove this:
home.file.".docker/config.json" = {
  text = "{}";
  force = true;
};

# Replace with:
home.activation.docker-config = lib.hm.dag.entryAfter ["writeBoundary"] ''
  if [ ! -f "$HOME/.docker/config.json" ] || [ -L "$HOME/.docker/config.json" ]; then
    mkdir -p "$HOME/.docker"
    rm -f "$HOME/.docker/config.json"  # Remove stale nix-store symlink
    echo '{}' > "$HOME/.docker/config.json"
  fi
'';
```

## Rebuild
```bash
cd ~/.config/home-manager-v3
nix run home-manager/master#home-manager -- switch --flake .#nixwsl
```

## Verify
```bash
ls -la ~/.docker/config.json  # Should be regular file, not symlink
test -w ~/.docker/config.json && echo "WRITABLE"
```

## Pattern
Any tool that needs to write to a home-managed path will fail if home-manager manages it via `home.file.*`. Use `home.activation` to create writable files instead.

Check for this pattern when debugging "Read-only file system" errors in NixOS for paths under `~/.config`, `~/.local`, etc.
