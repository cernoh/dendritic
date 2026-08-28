---
name: hm-out-of-store-symlinks
description: "Create home-manager symlinks to live absolute paths (mounts, /mnt, /etc) without store copies, plus GTK file-manager bookmarks for easy disk access. Use when adding disk/mount shortcuts to a home-manager host config or when worried home.file source strings get copied into the store."
---

# Home-Manager Symlinks to Live Paths (mounts, /mnt, /etc)

For a home-directory shortcut to an absolute, live path (a mounted disk, /etc resource, etc.) in a NixOS-integrated home-manager config.

## The trap

`home.file."x".source = "/abs/path"` — an absolute STRING source — makes home-manager run `builtins.path` on it, COPYING the contents into the nix store. Point it at a mounted disk and evaluation/activation copies the whole filesystem (a 2 TB mount = catastrophic). Relative strings resolve against the module path; only absolute strings store-copy.

## The fix

Use home-manager's out-of-store symlink helper for any absolute path:

```nix
# inside a home-manager block (host config or flake.homeManagerModules.*)
{ config, ... }: {
  home.file."2tb-storage".source = config.lib.file.mkOutOfStoreSymlink "/mnt/2tb-storage";
}
```

`config.lib.file.mkOutOfStoreSymlink` builds a tiny derivation whose output is a plain symlink to the target — no content copy, target need not exist at eval time. This is the repo convention for all live paths (ghostty, niri, noctalia, omp, opencode use it).

Note: to use `config.lib.file` inside a host's inline `home-manager.users.<name> = { ... }` block, the block must be a module function `{ config, ... }: { ... }` (the NixOS `config` at the key position is NOT the HM config).

## GTK file-manager bookmarks (thunar / GTK choosers)

```nix
xdg.configFile."gtk-3.0/bookmarks".text = ''
  file:///mnt/2tb-storage 2tb-storage
  file:///mnt/2tb-ext4 2tb-ext4
'';
```

Each line: `file://<uri> <label>`. Thunar and GTK file dialogs read this file. It becomes a read-only store symlink — thunar can't persist new bookmarks through it (acceptable tradeoff).

## Verification ladder

1. `nix-instantiate --parse <file>`
2. Eval the source resolves to a derivation (the `hm_*` drv), NOT a copy:
   ```bash
   nix eval --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.file.\"<name>\".source --impure
   ```
3. Build the output and readlink it:
   ```bash
   nix build --impure '.#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.file."<name>".source' --no-link
   ls -l /nix/store/<hash>-hm_<name>   # expects: lrwxrwxrwx ... -> /abs/target
   ```

Gotcha: `nix eval` does not accept brace-selector attr paths with quoted keys (`.{a = ...;}`); use escaped-quote plain paths (`.\"<name>\".source`).
