---
name: nix-store-and-gc
description: "Reason about immutable store paths, closures, profiles, garbage collection, and rollback safety"
---

# Nix store and garbage collection

Use when inspecting store paths, cleanup, generations, runtime state, or rollback behavior.

## Rules
- Treat `/nix/store` as immutable and broadly readable; never store mutable state or plaintext secrets there.
- A store path mentioned in text is not a GC root.
- Do not run broad garbage collection before identifying profiles, roots, and rollback requirements.
- Keep mutable runtime files on writable filesystems and materialize them through the correct activation mechanism.

## Procedure
1. Identify the profile or system generation that must remain usable.
2. Inspect references/closure and GC roots before deleting anything.
3. Prefer deleting obsolete generations through the platform's profile tooling.
4. Run garbage collection only after confirming rollback and runtime requirements.
5. Verify the active generation and affected runtime files afterward.

## Checks
Store paths may disappear after GC unless rooted. Generated configuration can be valid but still fail at runtime if a program expects to overwrite a store symlink.

## Renewal
Use current Nix store and garbage-collector manuals before applying cleanup commands. Source: https://nixos.org/manual/nix/stable/package-management/garbage-collector.html
