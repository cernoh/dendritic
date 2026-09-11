# noctalia — Noctalia desktop shell feature

## Purpose
Noctalia v5 desktop shell: bars, panels, launcher, lock screen. Exposes `flake.nixosModules.noctalia` (system install + `recommendedServices`) and `flake.homeManagerModules.noctalia` (declarative settings into `~/.config/noctalia/`). Owns the `cernoh/terminal` plugin and the `ghostty-term` helper it needs. Settings are per-host values.

## Ownership
- `default.nix` — NixOS/HM modules, the `ghostty-term` package, and the out-of-store plugin symlink.
- `_ghostty-term.pkg.nix` — derivation for the helper (single C translation unit against `pkgs.libghostty-vt`).
- `ghostty-term.c` — PTY and libghostty-vt helper; owns the frame protocol.
- `plugins/terminal/` — the `cernoh/terminal` plugin: `plugin.toml`, `service.luau`, `panel.luau`, `bar.luau`, `shortcut.luau`.
- `noctalia-full-config.toml` — reference dump of the ASAHI live config (data, not a source of truth).

## Local Contracts
- **Plugin directories hold Luau and TOML only.** The Noctalia plugin runtime has no foreign function interface, so a plugin cannot link a C library. Any native work goes in a separate derivation that the plugin spawns as a process.
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
- **The plugin is symlinked out-of-store** to `modules/features/noctalia/plugins/terminal` in this checkout, so plugin edits are live without a rebuild. The path is hardcoded to `~/.config/dendritic`, so a worktree copy is not live.

## Work Guidance
- Change the frame or command protocol: edit `ghostty-term.c` and `service.luau` together, and update the two contract lists above.
- Add a key the panel may forward: add a row to `KEY_TABLE` in `ghostty-term.c`, then add the same chord to `capture_keys` in `plugin.toml`. Use a chord name Noctalia documents as valid; an unknown name risks the manifest.
- The panel reads frames; it must not talk to the helper. New work goes through the service's request channel.
- Keep `plugin.toml` `plugin_api` at the lowest level that covers the features in use. The terminal plugin needs 21.

## Verification
- `nix-instantiate --parse modules/features/noctalia/default.nix`
- `nix-instantiate --parse modules/features/noctalia/_ghostty-term.pkg.nix`
- `nix build .#ghostty-term` — builds the helper with `-Werror`.
- `nix eval --impure .#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.packages` — the helper reaches the host.
- `nix flake check --impure`

## Child DOX Index
No children yet.
