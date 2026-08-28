---
name: dendritic-mango-env-wiring
description: "In the dendritic flake, make environment variables (TERMINAL, etc.) reach MangoWM spawn_shell bindings: the greeter-spawned compositor never sources profiles, so register vars into the mango feature's `settings.env` render (system-side since issue #97, validated by `mango -c -p` at build). Use when editing mango keybinds, wiring a terminal into SUPER+T, fixing spawn_shell bindings that expand to nothing, or adding an env var that must reach compositor-spawned processes."
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
`spawn_shell` inherit it. The mango feature owns the entries **statically**,
inside the system-side settings render (`modules/features/mango/default.nix`,
homeless-dotfiles policy #93 / issue #97 — there is no HM mango module
anymore; the config is evaluated into the store and mango is launched with
`-c <store config>`):

```nix
# env is a LIST, one "KEY,VALUE" pair per element
env = [
  "XCURSOR_SIZE,24"
  "TERMINAL,ghostty"
  # NVIDIA/Wayland GPU vars (host-scoped, NIXPC only)
  "GBM_BACKEND,nvidia-drm"
  ...
];
```

DO NOT inject into the settings from another feature behind a
`lib.mkIf (config ? ...)` guard: the module system counts mkIf-false
definitions of undeclared options as an "option does not exist" error, so the
guard breaks every host without mango (that exact failure was issue #86, fixed
by PR #87 — see the nix-mkif-guard-undeclared-option skill). Adding a new var
= edit the mango feature's env list.

Keep `home.sessionVariables.TERMINAL = "ghostty"` alongside (ghostty feature) —
it still serves login shells (SSH, PTYs). The same vars should also land in
`environment.sessionVariables` for login-shell/systemd-user consumers (issue
#95); the compositor channel is the one that actually reaches mango and its
spawns.

## Verification

- Eval (system render, issue #97): the config is a build-time-validated store
  file; check the settings attrset still renders:
  `nix eval --accept-flake-config --raw --impure '.#nixosConfigurations.NIXPC.config.programs.mango.package.drvPath'`
  → `mango-wrapped`, whose wrapper execs `mango -c <store config>`.
- Live reach on NIXPC:
  `tr '\0' '\n' < /proc/$(pgrep -x mango)/environ | grep TERMINAL`.
- Mango validates the rendered config at build (`mango -c -p` in the
  configFile derivation), so a malformed env entry fails the build, not
  runtime — same guarantee the HM module gave.

## Related

- The mkIf-guard failure mode: nix-mkif-guard-undeclared-option skill.
- Env that must reach compositor/systemd-user processes generally belongs
  system-side — see issue #95 and the mango `settings.env` pattern above.
- `$TERMINAL` is a shared contract: noctalia's cernoh/terminal panel widget
  also drives it. Its env comes from noctalia's own launch context, not mango's.