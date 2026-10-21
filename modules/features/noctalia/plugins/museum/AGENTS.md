# Museum plugin — `cernoh/museum`

A museum-themed reskin of the noctalia shell, built as an in-repo plugin
following the `cernoh/terminal` and `cernoh/mirai` pattern. Design and plan
live in the museum repo (`docs/DESIGN.md`, `docs/PLAN.md`); the rendered
artifacts under `artifacts/` are the acceptance target.

**This file carries the Phase 0 recon.** Every later phase reads these answers
before designing a surface. The recon was done against noctalia **5.3.0,
rev `ee75f7a`**, the build the host is running.

---

## Phase 0 recon answers

### 0.1 — Plugin API level: **34** (`kCurrentPluginApiVersion`)

Evidence chain, so the number is not a guess:

- `nix hash path /nix/store/030rad3scnli8qp931skk1niqqsyx6cv-source` =
  `sha256-sVeO0/25+P2l8JGIeJSChSNl0jj3EgNrKTDsRXyOQKo=`, exactly the
  `narHash` of the `noctalia` input in `flake.lock` (rev
  `ee75f7adcc012f2b02852b655769758cce7eb721`, branch `cachix`).
- `/nix/store/dibhdn8q08bkxd9man108akrvxh0rjaj-noctalia-5.3.0.drv` builds from
  that source and yields `/nix/store/d40ca1kxfc6dpv214w0s5g4m2wwswpna-noctalia-5.3.0`,
  which is what the running process (`readlink /proc/<pid>/exe`) executes.
  `noctalia --version` → `v5.3.0 (ee75f7a)`.
- `src/scripting/plugin_api.h:37` → `kCurrentPluginApiVersion = kWidgetHoverHighlightPluginApiVersion`;
  `:36` defines that as `34`. `:7` → oldest supported is `3`.

Levels that matter here (`src/scripting/plugin_api.h`):

| Level | Feature | Museum use |
|---|---|---|
| 6 | `string_map` setting | no |
| 8 | `dismiss_on_outside_click` | yes — drawer manifest |
| 10 | `keyboard_focus` | yes — drawer manifest |
| 13 | `capture_keys` | only if the drawer takes keys |
| 14 | widget gesture actions | no |
| 19 | `formatTime` with timezone | maybe — a plugin clock |
| 21 | plugin UI props (`maxWidth`, `maxLines`, `textAlign`, …) | yes |
| 22 | `require` modules (`lib/*.luau`) | yes |
| 23 | `readFileAsync` | yes — `/run/noctalia-drive-health/raw.json` |
| 26 | `getSetting` | only if a plugin setting is read |
| 30 | panel `layer` | no |
| 31 | `getColor` | only if Luau needs a hex |
| 34 | widget `hover_highlight` | no |

**Policy:** declare the lowest level the code actually needs (module AGENTS.md
work guidance). `26` is today's value and matches the terminal plugin; it
already covers `require` (22) and `getSetting` (26) and the drawer's manifest
fields. Raise it to `31` the day a script calls `noctalia.getColor`, not
before. Do not raise it for capability we merely *could* use.

### 0.2 — `ui.box` `softness`: accepted, documented, and **a no-op**

- Documented: `docs/user/plugins/development/declarative-ui.mdx:60` lists
  `softness` among `ui.box` props.
- Parsed and applied: `src/ui/ui_tree_reconciler.cpp:466-468` (known-prop set)
  and `:1306-1308` (`Box::setSoftness`), `src/ui/controls/box.cpp:71`.
- Why it does nothing: the rect shader uses it only in the **outer-shadow**
  branch — `src/render/programs/rect_program.cpp:274` (`aa = max(u_softness, 0.85)`)
  feeds the shadow's `smoothstep` at `:279-285`, while the box's own edge
  coverage (`coverage_for`, `:241-247`) is normalized to exactly one device
  pixel and never sees `aa`. A plugin box cannot turn `outerShadow` on
  (`outerShadow` is not in the box prop set).
- Live probe (`probe/museumprobe`, a throwaway panel, since deleted): three
  `ui.box` with `softness = 0 / 8 / 24` rendered pixel-identically.

**Consequence:** no soft edge, no glow, and no drop shadow from `ui.box`.
Depth is layered fills plus 1px borders — which is what DESIGN §4 already
says, so nothing is lost, but do not budget `softness` for a Plate shadow.

Probed in the same pass, also load-bearing:

- `ui.box` has **no `padding`** prop and **cannot have children** — host logs
  `ui tree: 'box' has no prop 'padding', ignored` and
  `ui tree: 'box' cannot have children, N dropped`
  (`ui_tree_reconciler.cpp:1101-1107`, `:854`). Boxes are leaf primitives.
- `padding`/`gap`/`align`/`justify` belong to `ui.column` / `ui.row` (the flex
  controls, `:461-465`). A **Plate is a `ui.column`**, never a box with
  children; a box is only ever a fill, a rule, or an accent.
- Unknown props are a loud skip, not a silent no-op — a typo surfaces in the
  journal as `ui tree: '<type>' has no prop '<name>', ignored`.

### 0.3 — No gradient in a plugin tree. Three amendments to DESIGN §5

`fill`/`border`/`track`/`color` all go through one parser
(`ui_tree_reconciler.cpp:155-190`): a **role token** with an optional
`/alpha` suffix (`primary/0.45`), or a hex `#rrggbb[aa]`. Anything else warns
`unknown color '<value>' for prop '<key>'` and the prop is skipped. Live
probe: `fill = "linear-gradient(90deg,#000000,#ffffff)"` logged exactly that
and the box drew **no** fill; `fill = "brass"` (a museum token, not a role)
did the same.

`FillMode::LinearGradient` exists in `src/render/core/render_styles.h` and is
used by core controls, but no `ui.*` prop selects it. So DESIGN §5's
"gradients not available" holds — with three corrections the design docs do
not yet carry:

1. **`ui.separator` is not a solid rule; it is a centre-peaked fade.**
   `src/ui/controls/separator.cpp:110-143` always paints a linear gradient
   because `m_gradientEdges` defaults to `true` (`separator.h:44`) and the
   plugin reconciler never sets it. Live pixel sample across a 720px
   separator: transparent at both ends, full role colour only at the centre.
   A plugin cannot turn the fade off.
2. **A 1px `ui.box` is the hairline.** `<box fill="outline" height=1 flexGrow=1>`
   rendered pixel-identical to the role across its whole width. This is the
   `Ledger` leader (and the "solid 1px separator" DESIGN §5 asks for — it just
   is not a `ui.separator`).
3. `softness` is not a shadow (0.2).

Deferred, not adopted: `ui.image{fit="stretch"}` can stretch a bitmap
(`path` resolves against the plugin dir) and `noctalia.writeFile` can write
one at runtime, so a pre-baked gradient strip is *technically* reachable.
It is deferred because the module contract allows Luau and TOML only in the
plugin directory; revisit only if a gradient becomes load-bearing.

### 0.4 — The rail has **11 entries**, and Media is one of them

- `src/shell/control_center/control_center_panel.h:109-146` declares twelve
  `TabId`s — `Home, Media, Audio, Monitor, System, Power, Network, Bluetooth,
  Weather, Calendar, Notifications, ScreenTime` — each with a rail glyph, and
  the rail is built from that one table (`control_center_panel.cpp:177-211`
  builds one `ui.button` per `kTabs` row into `m_tabButtons`;
  `syncTabVisibility`, `:568-584`, shows/hides them). Media is a first-class
  rail button, not a bar-only shortcut.
- Visibility is `isTabVisible` (`:507-522`): `Home` always, `hidden_tabs` for
  the rest, and `ScreenTime` only when `shell.screen_time_enabled` is true.
  The live config has `screen_time_enabled = false` and `hidden_tabs = []`,
  so **11 buttons show: Home + the ten DESIGN wings**.
- Live probe: `noctalia msg panel-open control-center media` lit the second
  rail button (the disc). The earlier capture that showed "no lit item" was a
  capture artifact; Media is railable and lights normally.

**Consequence:** nothing in the Wing Index has to be dropped. The museum rail
is the ten named wings of DESIGN §6.2, in our own order, with a Home
equivalent if we want one (>ten). noctalia's own order is Home, Media, Audio,
Monitor, System, Power, Network, Bluetooth, Weather, Calendar, Notifications —
the DESIGN order (System first) is a re-ordering the plugin owns.
`hidden_tabs` can hide any non-Home tab, which is the Tier-A lever for
"do not show noctalia's tab and the museum's wing twice".

### 0.5 — Built-ins to keep (do not rebuild what already reads correctly)

Live bar (`~/.config/noctalia/config.toml`, `[bar.main]`) vs the artifact's
after-bar:

| Built-in | Museum wants | Verdict |
|---|---|---|
| `launcher` | brass round search button | **keep** — already a round glyph button that takes `primary`/`on_primary` |
| `session` | brass power button | **keep** — glyph button; it *is* the power control |
| `tray`, `notifications`, `clipboard`, `volume`, `brightness` | tray plate / seal / audio plate | **keep** — group them with `[[bar.main.capsule_group]]` (already used for `g1`/`g2`); a plate around built-ins is config, not a plugin |
| `clock` | two-line brass placard | **keep with config** — see below |
| `workspaces` | roman-numeral hall plates | **replace** with `halls` — numerals + capsule are not plates |
| `active_window` | `NOW VIEWING` slip | **replace** with `label` — paper/caption is not reachable |
| `media` | exhibit plate, `No exhibit` when idle | **replace** with `exhibit`, or keep the pill and drop the empty state |

The clock deserves the detail because PLAN §3.4 asks for a decision:

- `format` accepts a **newline** and renders a stacked two-line clock
  (`src/shell/bar/widgets/clock_widget.cpp:20-27 splitFirstLine`), so
  `format = "%H:%M\n%A %e %B"` gives time + date with no plugin.
- A per-widget `color` beats the bar's capsule foreground
  (`src/shell/bar/widget.cpp:30-41 widgetForegroundOr`), so
  `[widget.clock] color = "primary"` gives the brass.
- What config cannot give: a serif face (the bar font is global) and a
  capsule of its own. **Decision for Phase 3: keep the built-in clock.** Write
  a plugin clock only if the serif is judged load-bearing after a live render.

So Phase 3's six widget entries become **five** (`halls`, `label`, `machine`,
`thermal`, `exhibit`) plus bar config; `tray` collapses into capsule groups
around the built-ins.

### 0.6 — Glyph names: two names in use are missing, and one module rule is stale

Resolution order is codepoint literal → noctalia's curated alias map →
`assets/fonts/tabler.json` (`src/render/text/glyph_registry.h:8-11`; aliases at
`glyph_registry.cpp:27-131`). 5958 Tabler names in the 5.3.0 asset. A name
outside all three logs `missing glyph: <name>` and draws nothing.

Live probe result:

- **missing:** `building-museum` (the skeleton's `plugin.toml` icon; the
  manifest now carries `building-bank`, which renders), `monitor`.
- **resolves through the alias map:** `close` → `x`, `weather-cloud-sun` →
  `cloud-sun`, `memory` → `cpu`, `gpu-usage` → `device-desktop`,
  `storage` → `database`, `volume-x` → `volume-3`, `volume-high` → `volume`,
  `volume-low` → `volume-2`, `volume-mute` → `volume-off`.
- **absent, do not use:** `monitor`, `display`, `hard-drive`, `gear`,
  `speaker`, `power-off`, `shutdown`, `gpu`, `building-museum`.

The ten wings reuse the shell's own tab glyphs, which are proven because the
live rail draws them: `activity-heartbeat` (System), `battery-charging-2`
(Power), `volume` (Audio), `device-desktop` (Display), `wifi` (Network),
`bluetooth`, `weather-cloud-sun`, `calendar-event`, `bell` (Notices), `disc`
(Media), `home`. Also verified present for the bar and drawer:
`search`, `power`, `x`, `player-play`, `player-pause`, `player-skip-back`,
`player-skip-forward`, `volume-2`, `volume-3`, `sun`, `brightness-up`,
`brightness-2`, `bell-off`, `disc-off`, `circle-check`, `circle-x`,
`chevron-left`, `chevron-right`, `arrow-up`, `arrow-down`, `temperature`,
`flame`, `cpu`, `database`, `server`, `settings`, `droplet`, `headphones`,
`vinyl`, `clock`, `calendar-month`, `photo`, `album`, `music`, `microphone`,
`phone`, `wifi-off`, `bluetooth-off`, `refresh`, `hourglass-empty`, `gauge`,
`scale`, `leaf`, `mug`, `mug-filled`, `moon`, `moon-off`, `contrast-filled`,
`terminal-2`, `plug-connected`, `box`, `shield-filled`, `file-description`,
`alert-circle`, `exclamation-circle`, `user`, `dots-vertical`, `pinned-off`,
`keyboard`, `building-monument`, `building-bank`.

**Stale rule to correct in the module `AGENTS.md`:** it says "`monitor` and
`close` are not in that set". On 5.3.0 `close` resolves through the alias map
to `x`; only `monitor` is missing. Fix that line the next time the module
contract is edited.

---

## What the recon changes in the design

Keep this list honest — an artifact that promises what the shell cannot draw
is a lie the next session will believe.

**Drop (Tier A cannot draw it, no gate pending):**

1. **Gradient fills.** The artifact's hall plates are
   `linear-gradient(180deg, brass-lt, brass)`; the shell can only fill a solid
   role. Flatten to `primary`, with a 1px `brass-lt` box inset as the
   highlight if the plate reads flat.
2. **`ui.separator` as the `Ledger` leader or as a "solid 1px rule".** It is a
   centre-peaked fade by design. Use a 1px `ui.box` with `flexGrow = 1`.
3. **Plate shadow / soft edge via `softness`.** It is a no-op for plugin boxes.
4. **Italic label text.** `ui.label` has no italic or style prop (only
   `fontWeight` in `thin|light|normal|medium|semibold|bold|heavy`). An italic
   face is reachable only by loading an italic font file as its own family
   (`noctalia.loadFont`) — treat the artifact's italic wall label as deferred
   until a font is loaded, not as free.

**Defer (Tier B, gated by PLAN §9):**

5. Needle dials on the instrument board (no arc primitive).
6. Rotation on the stamp, dashed stamp borders (no transform, no dashed stroke).
7. A true gradient anywhere in the plugin tree.

**Keep, with a correction to how it is built:**

8. `Ledger` leaders: 1px `ui.box`, not `ui.separator` (0.3).
9. `Plate`: a `ui.column` with `fill/radius/border/padding`, never a box with
   children (0.2).
10. Fonts: `noctalia.loadFont(path)` returns a family name that
    `ui.label{fontFamily=…}` accepts (`runtime-api.mdx:260`,
    `luau_host.cpp:1064-1084`). Cinzel / EB Garamond is a **dependency** (the
    font file must exist on disk), not a drop. Built-in bar widgets keep the
    bar font, so a serif bar means either the global `[shell] font_family` or
    plugin widgets.
11. Colours: pass **role strings** to `ui.*` and let the host resolve them live
    against the palette (`parseColor` → `colorRoleFromToken`). `noctalia.getColor(role)`
    exists for the rare case Luau needs a `#rrggbb` string — and it is what
    raises the declared API level to 31.

---

## Ownership

This is the **target shape** from PLAN §2.2 and the phase plan, not a listing of
the directory today — Phase 3/4 split the bar into one entry per component
family and the implementation may carry more files than this list.

- `plugin.toml` — manifest. `plugin_api = 26`; one `[[panel]]` (attached,
  keyboard-exclusive, dismiss-on-outside-click → needs **≥ 10**), bar-widget
  entries, a `[[shortcut]]`, `[[service]]`s, and plugin/widget settings.
- `bar.luau` — the bar widget entry (`barWidget.render(ui.*)`); Phase 3 replaces
  it with one entry per family (`halls`, `label`, `machine`, `thermal`,
  `exhibit`/`tray`).
- `panel.luau` — the catalogue drawer (`panel.render(ui.*)`, `onOpen`,
  `onClose`, `onKey`, `onScroll`).
- `service.luau` — background logic: drive-health, stats, timers. Owns every
  read; the panel never shells out.
- `shortcut.luau` — control-centre tile.
- `lib/museum.luau` — `Plate`, `Ledger`, `Meter`, `Lever`, `Slip` (Phase 2).
- `tests/*.luau` — plain `luau` assertions against a stub host (Phase 2.7).
- `translations/en.json` — all user-visible strings.

## Local contracts

- **Luau and TOML only** in this directory. No FFI exists; native work goes in
  a separate derivation the plugin spawns.
- **Width discipline.** The bar must fit 1920 logical px with every widget
  present. Cap plate widths in `lib/museum.luau`, not per instance.
- **The panel reads; the service fetches.** `/run/noctalia-drive-health/raw.json`
  (schema 2) is read, never re-collected; the collector belongs to
  `system/disk-health`.
- **`plugin_api` is a cost, not a badge.** See 0.1's policy.
- **Glyph names** come from `assets/fonts/tabler.json` or the alias map in
  `glyph_registry.cpp`; a name in neither is silently nothing but a journal
  line (0.6).
- **Hot reload is unreliable.** `noctalia msg plugins disable cernoh/museum`
  then `enable` after an edit; confirm with a visible change.
- **The plugin is symlinked out-of-store** from
  `modules/features/noctalia/default.nix`, so edits are live. One writer per
  file; a stray disable/enable mid-edit loses state.

## Work Guidance

- Building a component (PLAN Phase 2): check the prop against
  `docs/user/plugins/development/declarative-ui.mdx` and the known-prop set in
  `ui_tree_reconciler.cpp:459-535` before designing with it. An undocumented
  prop that is in the set works; a documented prop can still do nothing
  (`softness`).
- Bar entry: one entry per component family, so the bar stays
  user-reconfigurable. Keep built-in widgets where 0.5 says they read.
- Drawer section: assert the rendered tree in `tests/`, then screenshot live.
  `noctalia msg panel-toggle cernoh/museum:panel` opens it; hot reload
  does not always pick up an edited file.
- Add a glyph: verify it with
  `jq -e --arg g <name> 'has($g)' <noctalia>/share/noctalia/assets/fonts/tabler.json`
  or by checking the alias map first. Never introduce a name that only renders
  on one noctalia version.
- Change the palette: roles only; the four museum hexes (`brass-lt`, `paper3`,
  `patina`, and a true green ink if one is added) are the only allowed
  literals, and they belong in the palette file first (PLAN 1.1).

## Verification

- Parse/type-check:
  `nix shell nixpkgs#luau --command luau-analyze plugins/museum/*.luau`
  (only `Unknown global` for `noctalia`/`ui`/`panel`/`barWidget`/`shortcut`
  is expected).
- Manifest:
  `nix/store/<noctalia>/bin/noctalia plugins lint modules/features/noctalia/plugins/museum`
  — cross-checks `plugin.toml` against the `getConfig` calls and rejects an
  unparseable chord.
- Unit tests (Phase 2+):
  `cd plugins/museum/tests && nix shell nixpkgs#luau --command luau museum.luau`
  (bare `luau` resolves `require` from the working directory, so `require
  "../lib/museum"` has no `.luau` extension).
- Live: `noctalia msg plugins disable cernoh/museum && noctalia msg plugins
  enable cernoh/museum`, then `noctalia msg panel-toggle cernoh/museum:panel`,
  then `grim -o <connector>` (or `grim -g "x,y wxh"`) and read the image back.
- Journal: `journalctl --user -t noctalia --since -2min` is where
  `ui tree: … has no prop …`, `unknown color`, `cannot have children`, and
  `missing glyph` appear. Check it after every render change.
