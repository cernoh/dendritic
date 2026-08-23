---
name: noctalia
description: "Work across Noctalia v5 shell, noctalia-greeter, configuration, theming, IPC, plugins, Wayland compositors, and Nix/Home Manager integrations using the current official docs"
---

# Noctalia

Use this skill for any task involving Noctalia: the Noctalia v5 Wayland desktop shell, `noctalia-greeter`, Noctalia configuration, bars and widgets, theming, services, IPC, hooks, plugins, compositor integration, or Nix/Home Manager packaging and deployment.

## Documentation source of truth

The official documentation lives at:

- [Documentation repository](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs)
- [Noctalia v5](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia)
- [Noctalia shell getting started and development](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia-shell)
- [Noctalia Greeter](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/greeter)

Read the relevant page directly with the repository reader before making claims about option names, file locations, CLI commands, IPC endpoints, plugin APIs, or version behavior. Prefer the current `main` docs over memory. Check the page's version and migration notes; Noctalia v4 and v5 are separate installations and their settings are not automatically interchangeable.

Useful documentation areas:

- [Installation and running](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/getting-started)
- [Configuration](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/configuration)
- [Shell settings](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/shell)
- [Bars and widgets](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/bar)
- [Desktop, wallpaper, and dock](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/desktop)
- [Services](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/services)
- [Theming and palettes](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/theming)
- [IPC and automation](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/ipc)
- [Plugins](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/noctalia/plugins)
- [Greeter configuration](https://github.com/noctalia-dev/noctalia-docs/tree/main/src/content/docs/greeter/configuration.mdx)

## Identify the product first

Before editing anything, classify the request:

1. **Noctalia v5 shell** — desktop bars, panels, launcher, wallpaper, dock, lock screen, control center, widgets, services, themes, IPC, and hooks. Use `/noctalia/...` docs.
2. **Noctalia shell documentation/development** — installation, running, configuration concepts, themes, widgets, IPC, or contribution work. Use `/noctalia-shell/...` docs when the task targets that documentation section or its development guidance.
3. **Noctalia Greeter** — the greetd login UI and its compositor/session. It is not the desktop shell and not a compositor replacement. Use `/greeter/...` docs and keep its system-wide state separate from the user's shell state.
4. **Integration layer** — NixOS/Home Manager, compositor startup/keybinds, systemd/user services, D-Bus, polkit, fonts, cursors, portals, or package overlays. Trace both the Noctalia documentation and the local integration module/configuration.

Do not mix shell and greeter settings merely because they share visual styling. Treat their configuration files, privilege boundaries, users, and activation paths as separate until the docs explicitly describe a sync mechanism.

## Standard workflow

### 1. Establish local facts

- Inspect the repository and current branch before code changes. Never edit the default branch; follow the repository's issue/branch/PR rules when a remote exists.
- Find the active Noctalia version, package source, host/system target, compositor, and config owner.
- Inspect existing Noctalia modules and generated files before introducing a second representation. Reuse local naming, option shapes, and deployment commands.
- Check for user-managed edits in TOML, Nix, compositor config, and generated files. Preserve unrelated values.

### 2. Read the applicable docs

- Read the section index and the specific page for the requested behavior.
- Follow links for precedence, migration, platform-specific setup, and troubleshooting rather than inferring semantics from a nearby option.
- For a source-level or plugin task, inspect the corresponding upstream source and examples after reading the docs.
- Record exact option names, types, defaults, supported values, and whether a value is GUI-managed, declarative, generated, or runtime-only.

### 3. Make the smallest coherent change

- Change the source of truth, not only a generated artifact. Regenerate output when the project workflow requires it.
- Preserve TOML table structure and Nix serialization conventions. Do not copy an entire live TOML file into a declarative module when only selected settings were requested.
- Avoid speculative retries, compatibility aliases, fallback paths, or migrations outside the requested version and host.
- Keep compositor startup and keybind changes aligned with the documented command and IPC interface.
- For plugins, follow the documented plugin API and lifecycle; do not assume shell internals are stable public interfaces.
- For greeter changes, account for greetd, the greeter user, `/var/lib/noctalia-greeter`, polkit, D-Bus, accountsservice, and the compositor/session wrapper as applicable.

### 4. Verify end to end

Select checks that exercise the changed path:

- **Configuration:** validate the effective/generated TOML if a validator is available; inspect the exact affected tables and precedence behavior.
- **Nix/Home Manager:** evaluate or build the targeted host output, inspect generated `.config/noctalia/config.toml`, and avoid building unrelated hosts. Use the repository's existing deployment target.
- **Shell runtime:** launch or reload Noctalia, exercise the changed UI/command, and inspect logs for the relevant user service/process.
- **IPC/keybinds:** invoke the exact documented command or endpoint and observe the resulting state change.
- **Greeter:** verify greetd's command path, session selection, logs, permissions, state files, and the login-screen behavior. Test appearance sync separately from declarative `greeter.toml` precedence.
- **Theming:** test the selected theme/palette and any generated downstream app theme without overwriting unrelated user themes.
- **Plugins:** load the plugin in the supported runtime and exercise its visible widget, shortcut, service, or IPC behavior.

Report the exact command and scenario exercised. Distinguish a successful evaluation/build from a successful live activation.

## Nix and Home Manager guidance

- Inspect the current module before editing. Match its option names, nested attribute structure, list/object representation, and host-specific imports.
- Keep declarative configuration reproducible. Do not embed secrets, machine-local absolute paths, or untracked generated state unless the existing design requires them.
- Build the smallest relevant output first. For this repository, the existing Noctalia settings workflow commonly builds `.#homeConfigurations.asahi.activationPackage --no-link`, then inspects the generated TOML; use the actual host target for the task instead of blindly copying that example.
- If syncing live TOML into Nix, compare only requested sections, preserve custom widget definitions, and verify generated TOML after serialization. The specialized `sync-noctalia-settings` skill covers that narrow workflow.
- Activate only when requested or when the task explicitly requires deployment. Before activation, confirm the target host and revision.

## Troubleshooting order

1. Confirm the component and version.
2. Confirm the executable/package path and startup command.
3. Confirm the effective config file and precedence/load order.
4. Confirm environment, Wayland compositor, D-Bus, systemd user session, polkit, and permissions.
5. Inspect component-specific logs before changing configuration.
6. Reproduce with the smallest documented command or config.
7. Fix the root cause, then repeat the original scenario.

For a blank shell, check compositor startup, `WAYLAND_DISPLAY`, package/runtime dependencies, and user-service logs before changing visual settings. For a blank greeter, check greetd's wrapper path, `/var/lib/noctalia-greeter`, DRM/wlroots logs, and the greeter user before changing appearance. For polkit failures, distinguish missing policy, no graphical session, and a pending authorization prompt; seatd-only setups may require the documented terminal approval path.

## Boundaries

- Official docs and the checked-out source beat recollection.
- Do not claim an option or command exists without finding it in current docs or source.
- Do not treat warnings as success when the relevant command returned nonzero.
- Do not overwrite live or generated configuration wholesale.
- Do not conflate a build/evaluation result with activation or runtime proof.
- Do not modify system-wide greeter state while solving a per-user shell problem, or vice versa.
