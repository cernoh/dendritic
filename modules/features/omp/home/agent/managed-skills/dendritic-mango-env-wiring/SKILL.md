---
name: dendritic-mango-env-wiring
description: "In the dendritic flake, make environment variables (TERMINAL, etc.) reach MangoWM spawn_shell bindings: home.sessionVariables (→ ~/.profile) never reaches the greeter-spawned compositor, so register vars into wayland.windowManager.mango.settings.env statically in the mango feature. Use when editing mango keybinds, wiring a terminal into SUPER+T, fixing spawn_shell bindings that expand to nothing, or adding an env var that must reach compositor-spawned processes."
---

# Dendritic: getting env vars into Mango spawn_shell

## The trap

`home.sessionVariables` writes `~/.profile` only (plus HM's injection into
fish/nushell configs). Mango is forked directly by greetd's session worker
(no login shell), and `spawn_shell` runs a non-login `sh -c "$CMD"` that never
sources profiles. Any `$VAR` inside a mango bind resolves to empty → binding
silently does nothing.

Verified on NIXPC: `/proc/<mango-pid>/environ` had no TERMINAL while the
binding was `SUPER,T,spawn_shell,$TERMINAL`.

## The fix channel

Mango's config `env` setting does `setenv()` in-process; children spawned by
`spawn_shell` inherit it. The mango feature owns the entries **statically**:

```nix
# modules/features/mango/default.nix — env is a LIST, one "KEY,VALUE" pair per element
env = [
  "XCURSOR_SIZE,24"
  "TERMINAL,ghostty"
];
```

DO NOT inject into `wayland.windowManager.mango.settings.env` from another
feature behind a `lib.mkIf (config ? ...)` guard: the module system counts
mkIf-false definitions of undeclared options as an "option does not exist"
error, so the guard breaks every host without mango (that exact failure was
issue #86, fixed by PR #87 — see the nix-mkif-guard-undeclared-option skill).
Adding a new var = edit the mango feature's env list.

Keep `home.sessionVariables.TERMINAL = "ghostty"` alongside (ghostty feature) —
it still serves login shells (SSH, PTYs).

## Verification

- Eval: `nix eval --accept-flake-config --json .#nixosConfigurations.NIXPC.config.home-manager.users.davr.wayland.windowManager.mango.settings.env`
  → `["XCURSOR_SIZE,24","TERMINAL,ghostty"]`.
- Live reach on NIXPC:
  `tr '\0' '\n' < /proc/$(pgrep -x mango)/environ | grep TERMINAL`.
- Mango validates the rendered config at build (`mango -c -p`), so a malformed
  env entry fails the build, not runtime.

## Related

- The mkIf-guard failure mode: nix-mkif-guard-undeclared-option skill.
- Env that must reach compositor/systemd-user processes generally belongs
  system-side — see issue #95 and the mango `settings.env` pattern above.
- `$TERMINAL` is a shared contract: noctalia's cernoh/terminal panel widget
  also drives it. Its env comes from noctalia's own launch context, not mango's.