---
name: nix-overlays-and-platforms
description: "Keep Nix package sets, overlays, systems, and cross-build roles consistent across flake outputs"
---

# Nix overlays and platforms

Use when adding overlays, packages, systems, cross builds, or remote builders.

## Rules
- Instantiate nixpkgs once per intended package set; do not silently mix independently imported `pkgs` sets.
- Apply overlays before evaluating modules or packages that consume them.
- Enumerate supported systems explicitly; never assume the current host is the target.
- Distinguish build, host, and target platforms before attempting cross compilation.

## Procedure
1. List outputs with `nix flake show` and identify each `<system>` or host output.
2. Trace the package set passed into the target module/output.
3. Validate the overlay through that same `pkgs` set (`nix eval --show-trace .#<output>`).
4. For cross or remote builds, verify platform support and builder/daemon access before changing expressions.
5. Build one representative target and one native target when both are supported.

## Failure patterns
An overlay visible in one import is not automatically visible in another. A package existing on Linux does not imply Darwin or cross support. A build platform is not the host platform.

## Renewal
Use current platform and distributed-build documentation before adding a new system. Sources: https://nixos.org/manual/nixpkgs/stable/#chap-overlays, https://nixos.org/manual/nixpkgs/stable/#chap-cross, https://nix.dev/manual/nix/2.34/advanced-topics/distributed-builds.html.
