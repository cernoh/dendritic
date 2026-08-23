---
name: home-manager-worktrunk-integration
description: Configure Worktrunk and Fish shell integration in this Home Manager repository
---

1. Add user-level Worktrunk settings to `config/worktrunk.toml`.
2. In `home.nix`, manage `~/.config/worktrunk/config.toml` with `config.lib.file.mkOutOfStoreSymlink` pointing to the repository config.
3. In `config/fish.nix`, initialize Worktrunk with `wt config shell init fish | source` inside `interactiveShellInit`.
4. Validate with `fish -n <(wt config shell init fish)` and `nix-instantiate --parse home.nix config/fish.nix`.
