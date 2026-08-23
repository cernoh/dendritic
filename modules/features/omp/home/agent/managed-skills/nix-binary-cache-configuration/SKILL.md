---
name: nix-binary-cache-configuration
description: "Configure and verify shared Cachix binary caches in NixOS/Home Manager flakes, including daemon trust and root activation"
---

## Procedure

1. Check the current branch and repository remotes before editing. Preserve unrelated working-tree changes.
2. Locate existing `nix.settings` definitions and host composition. Reuse one shared module rather than duplicating cache lists.
3. Create or update a shared module such as `config/nix-binary-caches.nix`:
   - Set public Cachix URLs in `nix.settings.substituters`.
   - Set the same non-default caches in `trusted-substituters`.
   - Set the matching signing keys in `trusted-public-keys`.
   - Omit `https://cache.nixos.org`; Nix supplies it by default.
   - Define the cache URL list once with a `let` binding so the two settings cannot drift.
4. Verify each Cachix key with `https://app.cachix.org/api/v1/cache/<cache-name>` before committing it.
5. Import the shared module from `home.nix` and each NixOS system module that needs system-level caches. Add `cachix` to shared Home Manager packages only when the CLI is requested.
6. Distinguish evaluation configuration from the active Nix daemon configuration. A Home Manager module can evaluate `nix.settings`, but it does not change the daemon's `/etc/nix/nix.conf` until the owning NixOS/Darwin system configuration is activated. If logs say `ignoring untrusted substituter` or `ignoring the client-specified setting 'trusted-public-keys'`, inspect `nix config show` and activate the system-level module as root.
7. For NixOS hosts, activate the system cache policy before retrying user-level builds:

```bash
sudo nixos-rebuild switch --flake .#<host>
nix config show
home-manager switch --flake .#<home> -b backup
```

8. For NixPC greetd, evaluate:

```bash
nix eval --raw --impure '.#nixosConfigurations.nixpc.config.services.greetd.settings.default_session.command'
```

Confirm the command starts with an executable Tuigreet store path and its `--cmd` target is the intended session, such as `mango`.
9. Run syntax and flake checks:

```bash
nixfmt --check config/nix-binary-caches.nix
nix-instantiate --parse config/nix-binary-caches.nix
nix flake check --no-build --show-trace
```

10. Evaluate cache lists for affected Home Manager outputs and the NixOS system derivation. Treat deprecation and configuration warnings separately from failures. If root activation is unavailable, report that the configuration evaluates but the original build/switch is not fully verified.
