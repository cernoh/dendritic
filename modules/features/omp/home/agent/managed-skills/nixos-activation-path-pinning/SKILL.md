---
name: nixos-activation-path-pinning
description: "Pin binary paths in NixOS/HM activation scripts (minimal PATH, store curl/wget, non-fatal fetch)"
---

# Activation Script PATH Pinning

Use when writing `system.activationScripts.*.text` (NixOS) or `home.activation.*` (Home Manager) that calls any binary beyond shell builtins.

## Rule

Activation runs with a minimal PATH. `coreutils` (`mkdir`, `chmod`, `mv`, `uname`, `echo`) is usually present; `curl`, `wget`, and most other tools are NOT. Never call them bare.

## Recipe

1. Pin every non-coreutils binary to a store absolute path: `${pkgs.curl}/bin/curl`, `${pkgs.wget}/bin/wget`, `${pkgs.patchelf}/bin/patchelf`.
2. Belt-and-suspenders: export a pinned PATH at the top of the script so bare coreutils calls also resolve:
   `export PATH="${lib.makeBinPath [ pkgs.curl pkgs.wget pkgs.coreutils ]}:$PATH"`
3. Keep imperative network fetches non-fatal — an offline machine must not fail activation. Use a `downloaded` guard / `|| true`, and only `chmod`/`patchelf`/`mv` when the download file exists. `set -e`-style failure aborts the whole unit (`home-manager-*.service` exit-code, `nixos-rebuild` status 4).
4. Keep store-path `patchelf` calls (already absolute) alongside; probe-guard static binaries with `--print-interpreter`.

## Verify

- `nix-instantiate --parse <module>`
- `nixfmt --check <module>` (re-run `nixfmt` after edits — long-string inserts break formatting)
- `nix eval .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.activation.<name>.data --impure --raw` — confirm store-resolved paths, zero bare `run curl`
- `nix flake check --impure` — full ladder before rebuild
- Remove stray untracked `result` symlink before rebuild (dirties the tree and breaks deploy warnings).
