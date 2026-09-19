---
name: noctalia-plugin-in-dendritic
description: "Author, verify, and ship a Noctalia v5 plugin (Luau + plugin.toml) inside the dendritic flake, including a native CLI/daemon the plugin shells out to, the offline gates (noctalia plugins lint, luau-analyze, stub-host harness), and live verification in the running shell via a path source, focused-output detection, glyph-set checks, and pointer clicks located by accent-colour blobs. Use when asked to add or debug a plugin in modules/features/noctalia/plugins/ or to wrap a CLI a plugin drives."
---

# Noctalia plugin in the dendritic flake

Worked example: `modules/features/noctalia/plugins/mirai/` (panel over the Mirai Miracast CLI),
shipped with `_mirai.pkg.nix`, a pinned `mirai` flake input, and `home.file` symlinks. Read
`modules/features/noctalia/AGENTS.md` first; it is the contract for this subtree.

## Decide the seam before writing Luau

1. Read the plugin docs from source, never memory: `noctalia-dev/noctalia-docs`
   `src/content/docs/noctalia/plugins/development/{manifest,entries,declarative-ui,runtime-api,plugin-api}.mdx`
   and `src/data/plugin-api.json` for levels.
2. Pin the API level to the features actually used. `direct-argv` (`runAsync` argument array) is
   level 24; `panel-frame-tick` 18; `service-lifecycle` 17; `module-require` 22. Levels 31/32 were
   unreleased at shell 5.1.0, so declaring them gets the plugin refused.
3. A Luau sandbox has no socket client and no FFI. A plugin drives an external tool only through
   `noctalia.runAsync`/`runStream`/`runInTerminal`, so a daemon-backed tool needs its CLI packaged
   (`_<name>.pkg.nix`, `perSystem.packages.<name>`, `home.packages`) and that CLI must be on the
   *noctalia user service* PATH (`/etc/profiles/per-user/<user>/bin` from `home.packages`).
4. Use the argument-array `runAsync` form for dynamic values. To set env vars without a shell, run
   `{"env", "VAR=value", "<bin>", ...}`.
5. UI vocabulary: `ui.{column,row,scroll,label,markdown,glyph,image,box,separator,spacer,progress,button,graph,toggle,slider,select,input}`.
   There is no `ui.spinner`, no `collapsible`, no per-cell background. `select` `selectedIndex` and
   its `onChange` index are 0-based (`ui_tree_reconciler.cpp`). `toggle`/`slider`/`select` are
   value-driven; `ui.input` is uncontrolled.
6. Glyph names must exist in the running shell's `assets/fonts/tabler.json`. A wrong name logs
   `[WRN] [glyph] missing glyph: <name>` and draws nothing. `monitor` and `close` are NOT in the
   set (use `device-desktop`, `x`, `device-tv`, `cast`, `cast-off`, `refresh`, `link`, `users`,
   `alert-triangle`).

## Running a CLI under NixOS

- A Python tool that resolves helpers by absolute path compiles in `/usr/...`. Override with
  `wrapProgram --set VAR <store path>`; PATH alone is not enough.
- Check the real output paths instead of guessing: `nix build --no-link --print-out-paths <pkg>`
  then list the output (`libexec/gnome-network-displays-stream`, `bin/miracle-wifid`).
- Python deps (e.g. `dbus-python`) need
  `--prefix PYTHONPATH : "$out/lib:${python3Packages.dbus-python}/${python3.sitePackages}"`;
  `$out/lib` alone never finds them. Keep `$out/lib` even when the launcher script sets its own
  PYTHONPATH: the script resolves it relative to `dirname $0`, which breaks under
  `/run/current-system/sw/bin` symlinks.
- A CLI that dies before answering (`quit`) makes the action look failed. Confirm such transitions
  from the next poll, not from the CLI answer, or a traceback line reaches the UI.
- A privileged mode (Wi-Fi P2P, raw sockets) needs a root process; the panel cannot escalate.
  Offer an unprivileged start plus a `sudo` route through `noctalia.runInTerminal`, and pass the
  session variables (`WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS`) through
  `sudo env NAME=value ...` so a root child can still draw on the user's desktop.

## Offline gates (cheap, run before any live test)

```bash
nix build .#<pkg>
<noctalia-store-path>/bin/noctalia plugins lint modules/features/noctalia/plugins/<name>   # settings vs getConfig, entries, manifest
nix shell nixpkgs#luau --command luau-analyze --formatter=gnu modules/features/noctalia/plugins/<name>/*.luau
```
`luau-analyze` output is trustworthy only after filtering: `Unknown global 'noctalia|ui|panel|barWidget|shortcut'`
and `FunctionUnused` for `update`/`onClick`/`onOpen` are host-provided noise. Anything else is real.

## Stub-host harness (behaviour proof without a shell)

The sandbox has `loadstring` but no `io`, so build combined files: `stub + plugin.toml values + entry + driver`
(regenerate with a small Bun/Node script, or eval), then `luau run-panel.luau`.

The stub must provide `noctalia` (`getConfig`, `state.set/get/watch` with a fire helper, `tr`/`trp`
returning keys, `json.decode` from a fixture map, `nowMs` from a settable clock, `getenv`,
`runAsync`/`runInTerminal` recording argv, `commandExists`/`fileExists`), `ui.*` constructors that
return `{type, props, children}` trees, and `panel`/`barWidget`/`shortcut` recorders. Then assert:
each rendered row, each control's exact argv, the request/`request_rev` channel, and both daemon
transitions (busy cleared by the right poll result, timeout path).

## Live verification in the running shell

1. Never copy into or enable over the repo's own plugin id and never touch the HM-owned paths.
   Copy the plugin dir to `/tmp/<name>-dev/<plugin>/`, then
   `<noctalia>/bin/noctalia msg plugins source add <dev-name> path /tmp/<name>-dev` and
   `msg plugins enable <author>/<plugin>`. Both write app-owned entries to
   `~/.local/state/noctalia/settings.toml`; remove them afterwards (`plugins source remove`,
   `plugins disable`) and confirm no `<plugin>` line remains in that file.
2. If the plugin needs a binary that the host profile does not yet have, put it on the shell's PATH
   for the test only: `nix profile add --profile ~/.local/state/nix/profile <store path>` (that dir
   is in the noctalia service PATH), then `nix profile remove --profile … <name>`.
3. Hot reload is unreliable for a plugin loaded from a path source. Force it with
   `plugins disable` + `plugins enable`, and check `journalctl --user -u noctalia` for
   `loaded plugin '<id>' (N entries)` and for `missing glyph`/error lines.
4. `panel-toggle <author>/<plugin>:<entry>` opens on the **focused output**, and it stays open. Read
   `mmsg get all-layers` (needs `MANGO_INSTANCE_SIGNATURE`, available in
   `/proc/<noctalia-pid>/environ`) and screenshot the monitor that owns
   `noctalia-attached-panel` — screenshotting the wrong monitor wastes whole cycles.
5. Screenshot with `grim -o <connector>` and read it with `read "/tmp/x.png?q=…"`. Vision pixel
   estimates are noisy (±200 px): locate controls from pixels instead. Decode with
   `ffmpeg -i x.png -f rawvideo -pix_fmt rgb24 x.raw` and scan in Bun/Node for the palette
   accent (`primary` hex, e.g. `#c99a5b`) — a filled toggle or a primary button is a solid blob
   (width ≥ 24, height ≥ 16). Click its centre: `wlrctl pointer move <dx> <dy>` (relative, so read
   `mmsg get cursorpos` first) then `wlrctl pointer click`.
6. Shell colours are the sepia palette from `modules/features/scheme`: surface `#241d17`,
   surface_variant `#302619`, primary `#c99a5b`. A card is `surface_variant` at the control-centre
   card opacity (0.92 for `transparency_mode = soft` with an opaque bar), outline border, radius 12.
7. The shell's store path can vanish (garbage collection) while the process keeps running. Find a
   live copy with `ls -d /nix/store/*noctalia-5*/`, or `readlink /proc/<pid>/exe`.

## Repo gates and shipping

- Stage new files before any `nix build`/`nix eval`: the flake copies from git, so untracked files
  are invisible and the build fails with `path … does not exist`.
- Ladder: `nix-instantiate --parse` on every edited nix file, `nix run nixpkgs#nixfmt -- --check`,
  `nix eval .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath` (pure, both hosts),
  the generated-config build (`xdg.configFile."noctalia/config.toml".source` runs
  `noctalia config validate`), then `nix flake check --impure`.
- Issue-linked PR: STE-lint the body with `.github/scripts/ste-lint.py` (stdin form, blank-line
  separate list items), open the PR with `Closes #<n>`, then tag the title with `(#<pr number>)`.
