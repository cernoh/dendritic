---
name: nix-mkif-guard-undeclared-option
description: "Diagnose and fix \"The option ... does not exist\" errors in NixOS/home-manager modules caused by lib.mkIf (config ? undeclared-option) guards — the module system counts mkIf-false definitions in the unknown-option check, so the guard does not protect hosts that never import the declaring module. Triggers on 'option does not exist', 'Definition values', 'condition = false', or option-existence guards that fail cross-host."
---

# Nix: `mkIf (config ? opt)` guards don't protect undeclared options

## Symptom

Evaluating a host fails with:

```
error: The option `...<name>.<undeclared>' does not exist. Definition values:
- In `<module>.nix, via option flake.<module>':
    { ..., _type = "if"; condition = false; ... }
```

The error appears on hosts that never import the module that would declare the option — even though the guard's condition evaluated `false`.

## Root cause

nixpkgs' module system checks definitions against declared options BEFORE mkIf filtering: any definition of an undeclared option path, including a `lib.mkIf false` one, raises the error. `lib.mkIf (config ? path)` only toggles the definition value at merge time; it does not exempt the definition from the existence check. `?` on a declared namespace (e.g. `wayland.windowManager` exists via niri) does not help either.

Minimal repro (evaluates to failure):

```nix
{ config, lib, ... }: {
  ghost = lib.mkIf (config ? nope) [ "x" ];  # error: option `ghost' does not exist
}
```

## Fix pattern

Move the definition into the module that DECLARES the option, unconditionally, and document the coupling. E.g. a terminal feature previously injected `TERMINAL` into a compositor's `settings.env` behind a guard; the compositor feature now owns the entry statically (host pairs the compositor with that terminal anyway). Chosen over declaring the option in both modules (duplicate declarations with identical types also merge, but the move is simpler and self-documenting).

## Verification

- `nix eval --accept-flake-config --raw .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath` for BOTH the host with and the host without the module (CI-style, pure).
- Confirm the affected merged value on the host that has the feature: `nix eval --accept-flake-config --json .#nixosConfigurations.<HOST>.config.home-manager.users.<u>.<option-path>`.
- `nix flake check --impure` if CI runs it.

## Notes

- This pattern bit a real flake: a "guarded" env injection broke the non-compositor host's toplevel eval and turned CI red on main, unnoticed until a full host eval ran.
- `mkIf false` on a DECLARED option is harmless — the trap is specifically undeclared option paths.
