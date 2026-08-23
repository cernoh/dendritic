---
name: nix-substitution-silently-broken
description: "Diagnose and work around nix builds that ignore binary-cache substitution on this machine (HM-generated ~/.config/nix/nix.conf omits cache.nixos.org), causing massive from-source builds with misleading upstream 404/hash-mismatch errors"
---

# Nix substitution silently broken (builds everything from source)

## Symptom
- `nix build` plans hundreds of derivations "will be built" including core packages (bash, glibc, gnu-config) that ARE in cache.nixos.org.
- Failures point at unrelated upstream rot: `git.savannah.gnu.org ... config.sub: HTTP 404`, stage0-posix tarball `hash mismatch`, mes/tinycc bootstrap failures. These are RED HERRINGS.
- Warnings: `ignoring untrusted substituter 'https://X.cachix.org'` + `ignoring the client-specified setting 'trusted-public-keys/substituters'`.

## Root cause (this machine)
Home Manager generates `~/.config/nix/nix.conf` from `nix.settings.substituters` listing ONLY cachix hosts — `cache.nixos.org` is missing. For non-root users the effective substituter list ends up without the official cache, so nix falls back to building from source; any broken upstream fetch in that path surfaces as the failure.

## Diagnosis recipe
1. Pick a failing output hash and check the cache directly:
   `curl -sS https://cache.nixos.org/<outHash>.narinfo` → 200 with `Sig:` line means substitutable.
2. Re-run the build and search the log for `copying path ... from` / `downloading`. Zero hits = substitution never consulted.
3. Read `/etc/nix/nix.conf` (daemon, usually fine: `substituters = https://cache.nixos.org/`) AND `~/.config/nix/nix.conf` (client override, the culprit here).
4. Confirm with a one-shot override:
   `NIX_CONFIG="substituters = https://cache.nixos.org" nix-store -r <drv>` → prints `copying path ... from 'https://cache.nixos.org'`.

## Workaround (per command)
```bash
export NIX_CONFIG="substituters = https://cache.nixos.org"
nix build ...
```
Works despite the "not a trusted user" warnings.

## Permanent fixes
1. **Flake-level (in any flake you control):** add a top-level output so every consumer prompt-accepts correct caches once, independent of their client conf:
   ```nix
   # flake.nix outputs attrset
   nixConfig = {
     substituters = [ "https://cache.nixos.org" /* first! order matters */ "https://nix-community.cachix.org" ];
     trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];
   };
   ```
2. **Machine-level:** in home-manager-v3 add `https://cache.nixos.org` (+ its key) to `nix.settings.substituters`/`trusted-public-keys`, then `home-manager switch`. Until then non-flake nix usage still needs the workaround.

## Notes
- `hello`/small packages may still succeed via local builds — success of one package proves nothing about substitution health.
- `nix flake check` warns `unknown flake output 'homeManagerModules'`; harmless, HM modules aren't checkable outputs.
