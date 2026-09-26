# noctalia — Noctalia desktop shell feature

## Purpose
Noctalia v5 desktop shell: bars, panels, launcher, lock screen. Exposes `flake.nixosModules.noctalia` (system install + `recommendedServices`) and `flake.homeManagerModules.noctalia` (declarative settings into `~/.config/noctalia/`). Owns the `cernoh/terminal` plugin and the `ghostty-term` helper it needs, and the `cernoh/mirai` plugin with the `mirai` Miracast CLI it drives. Settings are per-host values.

## Ownership
- `default.nix` — NixOS/HM modules, the `ghostty-term` and `mirai` packages, the out-of-store plugin symlinks, and the system-side brightness dependencies.
- `_ghostty-term.pkg.nix` — derivation for the helper (single C translation unit against `pkgs.libghostty-vt`).
- `ghostty-term.c` — PTY and libghostty-vt helper; owns the frame protocol.
- `_mirai.pkg.nix` — derivation for the Mirai daemon and CLI, built from the `mirai` source input.
- `plugins/terminal/` — the `cernoh/terminal` plugin: `plugin.toml`, `service.luau`, `panel.luau`, `bar.luau`, `shortcut.luau`.
- `plugins/mirai/` — the `cernoh/mirai` plugin: `plugin.toml`, `service.luau` (CLI poll + actions), `panel.luau` (the Bluetooth-style panel), `bar.luau`, `shortcut.luau`, `translations/en.json`.
- `plugins/auto-brightness/` — the `cernoh/auto-brightness` plugin: `plugin.toml`, `service.luau` (ambient-light display + keyboard backlight from the ALS IIO sensor; ASAHI-only).
- `noctalia-full-config.toml` — reference dump of the ASAHI live config (data, not a source of truth).

## Local Contracts
- **The feature owns monitor brightness.** The NixOS module installs `ddcutil` into `environment.systemPackages` and sets `hardware.i2c.enable`, because the noctalia user service carries no shell PATH and DDC/CI needs `/dev/i2c-*`. A host turns the DDC/CI path on with `brightness.enable_ddcutil = true` in its `_noctalia-settings.nix`; the kernel backlight interface covers internal panels only. Both hosts have an `i2c-dev` kernel (`=m` on NIXPC, built in on ASAHI), so no kernel patch is needed.
- **The `noctalia` input tracks the upstream `cachix` branch and the `noctalia-greeter` input tracks `main`; neither follows `nixpkgs`.** Upstream publishes both packages to `noctalia.cachix.org` against its own locked nixpkgs, so a follow changes the store path and forces a local build (issue #179).
- **Plugin directories hold Luau and TOML only.** The Noctalia plugin runtime has no foreign function interface, so a plugin cannot link a C library. Any native work goes in a separate derivation that the plugin spawns as a process.
- **Auto-brightness is ASAHI-only.** Only ASAHI has an ambient light sensor, so only `asahiConfiguration.nix` symlinks `plugins/auto-brightness` out-of-store and only ASAHI `_noctalia-settings.nix` lists `cernoh/auto-brightness` in `plugins.enabled`; NIXPC gets neither.
- **`ghostty-term` is the bridge.** It owns the pseudo-terminal and a `libghostty-vt` terminal, and writes one JSON frame per screen change on stdout. `pkgs.libghostty-vt` is a standalone package, separate from `pkgs.ghostty`; the `ghostty` build ships only the sequence parsers under the same soname, and its `vt.h` includes headers it does not install. The helper is offered only where `lib.meta.availableOn` reports `pkgs.libghostty-vt` (no x86_64-darwin build).
- **Frame protocol** (one JSON object per stdout line). `service.luau` is the only reader:
  - `{"t":"init","c":cols,"r":rows}` — geometry, sent once at start.
  - `{"t":"f","s":seq,"c":cols,"r":rows,"dfg":"#rrggbb","dbg":"#rrggbb","L":[row,...]}` — screen. `L` holds one array per row; each row holds text runs of `{"t":text,"f":"#rrggbb","b":true}`. `f` appears only when a run differs from `dfg`; `b` only when bold. `seq` is monotonic, and the service drops a frame that is not newer.
  - `{"t":"exit"}` — the shell exited.
- **Command protocol** (one command per line on the FIFO at `<pluginDataDir>/term.fifo`):
  - `i<escaped text>` — write text to the shell. Escapes: `\n`, `\r`, `\t`, `\e`, `\\`. A bare newline ends the command, so a newline meant for the shell travels as `\n`.
  - `k<key name>` — send an encoded key event (see `KEY_TABLE` in `ghostty-term.c`). libghostty encodes it for the mode the running program selected, so the helper never hardcodes escape bytes.
  - `s<n>` — scroll the viewport by `n` rows. `z<COLS>x<ROWS>` — resize. `f` — emit a frame now. `q` — quit.
- **Frames are coalesced at 80 ms** (`FRAME_MIN_MS`). A build log dirties the screen on every write, and the panel rebuilds its whole tree per frame. A gated write stays pending, so the last update always arrives.
- **Entries exchange plain values only.** `noctalia.state` copies values and forbids functions, so the panel posts work to the `request` key and bumps `request_rev`. The counter is required: two identical requests in a row must both run.
- **Render within the panel API's limits.** There is no canvas, no grid, and no per-cell background, and `ui.label` has no per-span styling. The panel draws one `ui.row` per terminal line and one `ui.label` per colour run, in a gap-free row, so a monospace font keeps the columns aligned. Backgrounds, italics, and underlines are not transmitted because nothing can draw them.
- **Only declared chords arrive.** `plugin.toml` `capture_keys` lists what the panel forwards; Noctalia delivers only those, sends them to `onKey(chord, pressed)`, and never sends a key it did not list. `escape` is reserved for the panel-close action and cannot be captured, and super chords belong to the compositor. A focused `ui.input` receives printable keys first, so typing goes through the input and `capture_keys` carries arrows, tab, and control chords.
- **The plugin is symlinked out-of-store** to `modules/features/noctalia/plugins/terminal` in this checkout, so plugin edits are live without a rebuild. The path is hardcoded to `~/.config/dendritic`, so a worktree copy is not live. `plugins/mirai` is symlinked the same way.
- **`mirai` expects its helpers under `/usr`.** `mirai/config.py` compiles in `/usr/bin/miracle-wifid`, `/usr/bin/miracle-sinkctl`, and `/usr/lib/gnome-network-displays-stream`, and the daemon probes `iw`, `ip`, `avahi-browse`, `wlr-randr`, `gst-launch-1.0`, `gst-inspect-1.0`, and `mpv` by bare name. `_mirai.pkg.nix` sets those paths and the PATH for the CLI, so the wrapper carries its closure wherever it is invoked, including through `sudo`. `dbus-python` belongs on the wrapper's PYTHONPATH; `$out/lib` alone is not enough.
- **The Mirai plugin drives the CLI, never the socket.** Mirai serves newline-delimited JSON on a Unix socket, and the Luau sandbox has no socket client, so `service.luau` runs `mirai status` and the action commands and publishes the parsed answer on the `snapshot` state key. The `socket` setting only overrides `MIRAI_SOCK`.
- **Sink mode needs a root daemon.** `miracle-wifid` needs Wi-Fi P2P, and Mirai refuses `sink-start` from a non-root daemon with a message naming `sudo`. The panel starts an unprivileged daemon (casting works), and offers a root daemon through `sudo` in a terminal, passing `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`, and the other session variables the sink player needs. A refused `sink-start` sets the `needs_root` state key, which renders the hint row and the root button.
- **`mirai quit` never answers.** The daemon closes the socket before it replies, so the CLI raises and the poll is the only confirmation of a stop. The service waits for a poll that reports the daemon down instead of reading the CLI answer, which keeps a Python traceback off the panel.
- **The panel copies the Bluetooth tab of the control center.** Cards follow `applySectionCardStyle`: fill `surface_variant` at the control-center card opacity (`0.92` for `transparency_mode = soft` on an opaque bar), outline border, radius 12, padding 12, gap 8. Rows follow `BluetoothDeviceRow`: a `surface` row with radius 6, a kind glyph, the name (bold while active), metric pills, then the actions. Every glyph name must exist in the shell's `assets/fonts/tabler.json`; an unknown name logs `missing glyph` and draws nothing (`monitor` and `close` are not in that set).
- **The terminal panel is a clickable dropdown pane without a visible input box.** Its printable and control key handling is declared in `plugins/terminal/plugin.toml`; its clickable surface uses existing Noctalia semantic tokens so future herdr controls can be added without changing the PTY seam.

## Work Guidance
- Change the frame or command protocol: edit `ghostty-term.c` and `service.luau` together, and update the two contract lists above.
- Add a key the panel may forward: add a row to `KEY_TABLE` in `ghostty-term.c`, then add the same chord to `capture_keys` in `plugin.toml`. Use a chord name Noctalia documents as valid; an unknown name risks the manifest.
- The panel reads frames; it must not talk to the helper. New work goes through the service's request channel.
- Keep `plugin.toml` `plugin_api` at the lowest level that covers the features in use. The terminal plugin needs 21. The Mirai plugin needs 24 (the argument-array form of `runAsync`, which keeps setting values out of a shell).
- Pick glyph and action glyph names from the shell's `assets/fonts/tabler.json` in `noctalia-dev/noctalia`; the shell logs `missing glyph` and draws nothing for a name outside that set.
- Add a Mirai control: post a new `kind` from `panel.luau`, run the matching `mirai` command in `service.luau`, and add its translation keys to `translations/en.json`.

## Verification
- `nix-instantiate --parse modules/features/noctalia/default.nix`
- `nix-instantiate --parse modules/features/noctalia/_ghostty-term.pkg.nix`
- `nix-instantiate --parse modules/features/noctalia/_mirai.pkg.nix`
- `nix build .#ghostty-term` — builds the helper with `-Werror`.
- `nix build .#mirai` — builds the Mirai CLI. The command then answers: `mirai status` prints the daemon JSON, `mirai sink-start` on an unprivileged daemon returns the root error, and `mirai source-scan --timeout 5` returns `{"ok":true,"scanning":true}`.
- `nix eval --impure .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.packages` — the helper and the CLI reach the host.
- Plugin checks, offline: `nix/store/<noctalia>/bin/noctalia plugins lint modules/features/noctalia/plugins/<name>` cross-checks the manifest against the `getConfig` calls, and `nix shell nixpkgs#luau --command luau-analyze modules/features/noctalia/plugins/<name>/*.luau` parses and type-checks the scripts. Only `Unknown global` reports for the host namespaces (`noctalia`, `ui`, `panel`, `barWidget`, `shortcut`) and `FunctionUnused` for the host-called globals are expected.
- Plugin behaviour, offline: run one entry script against a stub host and assert on the state it publishes and the trees it renders. The drivers used for the Mirai plugin kept a stub for `noctalia.*`, `ui.*`, `panel`, `barWidget`, and `shortcut`, answered `runAsync` from a fixture queue, and checked each rendered row, the command behind each control, and the poll and timeout paths.
- Plugin live: register the plugin directory as a path source (`noctalia msg plugins source add <name> path <dir>`), enable it, and open the panel with `noctalia msg panel-toggle cernoh/<plugin>:panel`. The panel opens on the focused output, so read `mmsg get all-layers` for the `noctalia-attached-panel` entry to learn which output to capture. Hot reload does not always pick up an edited file; `plugins disable` then `enable` forces it. Screenshot with `grim -o <connector>` and read the image.
- Brightness wiring: `nix eval --impure .#nixosConfigurations.<HOST>.config.hardware.i2c.enable` returns true, and `nix eval --impure .#nixosConfigurations.<HOST>.config.boot.kernelModules` lists `i2c-dev`.
- Brightness config: `nix build --no-link --impure --expr 'let f = builtins.getFlake (toString ./.); in f.nixosConfigurations.NIXPC.config.home-manager.users.davr.xdg.configFile."noctalia/config.toml".source'` — the build runs `noctalia config validate`, so a bad `brightness` key fails here.
- Live brightness on the host: `ddcutil detect` lists the monitors, `noctalia msg brightness-set <connector> 60` changes one, and the Control Center Monitor tab shows a slider per monitor.
- `nix flake check --impure`

## Child DOX Index
No children yet.
