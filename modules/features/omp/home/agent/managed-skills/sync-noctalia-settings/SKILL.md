---
name: sync-noctalia-settings
description: "Sync selected Noctalia TOML settings into the home-manager Nix module, merge, and activate safely"
---

## Procedure

1. Compare the source TOML with `config/noctalia.nix`; identify only the requested sections and changed keys.
2. Do not copy the entire TOML. Exclude stale or mixed-schema sections unless explicitly requested.
3. Preserve the module's existing Nix representation, especially object-style bar widget lists.
4. If a bar list references a custom widget, add its definition under `settings.widget` in Nix.
5. Build with `nix build .#homeConfigurations.asahi.activationPackage --no-link`.
6. Inspect the generated `.config/noctalia/config.toml` and compare the affected block with the source TOML.
7. If available, run `noctalia config validate` against the generated TOML. Treat warnings separately from a nonzero validation failure.
8. For deployment, merge the clean pull request, fetch `origin/main`, and run `home-manager switch --flake .#asahi` from a checkout at the merged revision.
9. Verify the live `/home/da/.config/noctalia/config.toml` contains the requested bar values and custom widget tables.
