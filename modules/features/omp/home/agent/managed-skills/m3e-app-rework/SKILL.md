---
name: m3e-app-rework
description: "Rework an existing Android Compose app into Material 3 Expressive end to end: capture every screen (emulator walk, or the user's own screenshots when the walk is impossible), pull candidate components and tactics from the expressive catalog grounded at file:line, then settle them in one served selection page that previews each candidate with live M3E web components and returns the user's choices as a single message. Use when asked to convert or rework an app to M3E, to inventory app screens before a design sweep, or when the user must choose which expressive features to apply."
---

# Rework an app into Material 3 Expressive

Four phases, in order. The screens come first, the candidates second, the user's choices
third, the plan last. Do not skip phase 1: a candidate that is not tied to a captured screen
is a guess.

```
1 screens ──▶ 2 candidates ──▶ 3 selection page ──▶ 4 plan
   (shots)      (catalog+tactics)   (one message back)   (rows + verification)
```

Sources of truth, in this order:

- the guide, `https://m3.material.io/blog/building-with-m3-expressive`, for **what** to
  change (14 expressive components, 4 expressive styles, 7 tactics, hero moments);
- the catalog, `github.com/meticha/material-3-expressive-catalog`, for **how** to write it in
  Kotlin Compose;
- the M3E web components, `github.com/matraic/m3e`, for **showing** it to the user.

## Phase 1 — Every screen, captured

**Enumerate from source first.** Read the navigation graph, so the inventory is complete
before you touch a device. Grep for the app's own vocabulary:

```
grep -rn "NavHost(\|composable(\|NavDisplay(\|entryProvider\|Serializable" <src>
grep -rn "sealed class .*Screen\|sealed interface .*Route\|@Serializable data class .*Route" <src>
```

One row per destination, then add the surfaces that have no route: modal bottom sheets,
dialogs, menus, toolbars and their overflow, the empty, loading, error and permission states,
and the first-run flow.

**Walk it on an emulator.** Build and install, then drive the app destination by destination.
The mechanics are already measured:

- `skill://nixos-agp-emulator-screenshot-loop` — dev shell, the `-Pandroid.aapt2FromMavenOverride`
  fix, headless boot, `screencap`, and the rule that tap coordinates come from
  `uiautomator dump` bounds, never from a scaled vision read.
- `skill://android-emulator-screenshot-state-seeding` — bypass a first-run wizard, seed a
  fixture, and prove which build is installed before trusting a capture.

```bash
adb -s emulator-5554 shell uiautomator dump /sdcard/ui.xml
adb -s emulator-5554 pull /sdcard/ui.xml /tmp/ui.xml        # bounds="[x1,y1][x2,y2]" in real pixels
adb -s emulator-5554 shell input tap <cx> <cy>
adb -s emulator-5554 exec-out screencap -p > <dir>/shots/<id>.png
```

Record the tap path for every capture (`reach` in the ledger). A screen reached by a tap path
is reproducible; a screen captured by accident is not.

**When the walk is impossible, collect from the user.** These are the blockers that end the
emulator route, and each one is a fact to state, not to hide: no `/dev/kvm`; no JDK or SDK on
the host; the build fails; the app needs an account, a backend, or a paid entitlement; the
screen depends on a provider the emulator cannot reach. Then:

1. Serve the collector (`assets/collector.ts`) on the round directory.
2. The page lists every destination that has no capture, with a file picker per destination.
3. The user drops the PNGs; the page posts them to `/api/shot?name=<id>`, which writes
   `shots/<id>.png` and updates `manifest.json`.
4. Wait for the manifest, or ask the user to say when the set is complete.

The plain fallback needs no server: print the exact target path and names
(`<dir>/shots/<id>.png`) and read the folder afterwards. Keep it as the documented alternative
when Deno is unavailable.

**Capture hygiene.** One PNG per screen, real pixels. Downscale for the ledger so the JSON
stays readable — `nix shell nixpkgs#imagemagick -c magick <in>.png -resize 540x <out>.png`,
then inline it as a `data:image/png;base64,…` URI. A blank capture still writes a file: check
the size, and never claim a screen that did not render.

## Phase 2 — Candidates, grounded in the catalog

**Ground the version before you name an API.** Never recall which expressive API exists. Two
existing skills carry the recipes:

- `skill://compose-m3-expressive-migration-recon` — is the theme already expressive, which
  BOM resolves which `material3`, the API census, the host's emulator capability.
- `skill://compose-m3e-migration-grounding` and `skill://material3-expressive-version-line-forensics`
  — per-module resolution, the `internal`-vs-public trap, the opt-in marker, and how to pin
  the version once. `skill://android-artifact-api-surface-forensics` has the artifact probes.

```bash
curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom \
  | sed -n '/<artifactId>material3<\/artifactId>/,+1p'
```

The catalog is a **reference, not a dependency**. Measured 2026-09-21: it builds on
`androidx.compose:compose-bom-alpha:2025.06.02`, Kotlin 2.1.21, AGP 8.10.0, `minSdk 31`,
Navigation 3, Hilt, and it opts in globally with `-Xopt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi`.
A target app on another BOM, another minSdk, or Voyager navigation cannot vendor these files;
read the API shape and write your own wrapper.

**A candidate is a row.** For each candidate, record all of: the family, the Kotlin API and
its import plus opt-in marker, the catalog file that demonstrates it, the current
implementation as `file:line`, the screens it touches, the effort and the risk, and the
evidence (production call sites versus `@Preview`-only uses — the split is decisive, because
hand-rolled components often collapse to one real consumer). Method and worked examples:
`skill://sealplus-m3-component-replacement-inventory`.

**The families to sweep, with their Kotlin entry points.** Measured 2026-09-21 against the
`material3-android-1.5.0-alpha14-sources.jar` (the newest published line — no `1.5.0` stable
exists): every API below is present there, and `ButtonGroup`, `SplitButtonLayout`,
`LinearWavyProgressIndicator`, `LoadingIndicator` and `MaterialShapes` carry
`@ExperimentalMaterial3ExpressiveApi`. A target repo on a stable BOM resolves an older
`material3`, where most of these are absent, so confirm against its own sources jar before you
name them in the ledger.

| Family (catalog dir) | Kotlin API | Preview element |
| --- | --- | --- |
| `buttons` | `Button`, `ButtonDefaults.shapes()`, `toggleableShapes()` | `m3e-button` |
| `buttongroup` | `ButtonGroup { }` | `m3e-button-group variant="standard\|connected"` |
| `fab`, `largefab` | `FloatingActionButtonMenu`, `ToggleFloatingActionButton`, `ExtendedFloatingActionButton` | `m3e-fab-menu`, `m3e-fab extended` |
| `splitbutton` | `SplitButtonLayout` + `SplitButtonDefaults.LeadingButton/TrailingButton` | `m3e-split-button` |
| `bottomappbar` | `BottomAppBar`, `FlexibleBottomAppBar` | `m3e-toolbar`, `m3e-nav-bar` |
| `floatingtoolbar`, `verticalfloatingtoolbar` | `HorizontalFloatingToolbar`, `VerticalFloatingToolbar` | `m3e-toolbar` |
| `navigationrail`, `widenavigationrail` | `NavigationRail`, `WideNavigationRail`, `ShortNavigationBar` | `m3e-nav-rail mode="auto\|compact\|expanded"`, `m3e-nav-bar` |
| `progressindicators` | `LinearWavyProgressIndicator`, `CircularWavyProgressIndicator`, `LoadingIndicator`, `ContainedLoadingIndicator` | `m3e-linear-progress-indicator variant="wavy"`, `m3e-loading-indicator` |
| `colors` | `expressiveLightColorScheme`, `MaterialExpressiveTheme(motionScheme = MotionScheme.expressive())` | `m3e-theme color="#6750A4" motion="expressive"` |
| shapes (blog: 35 shapes) | `MaterialShapes.Cookie4Sided.toShape()` | `m3e-shape name="4-sided-cookie"` |
| app bars (blog) | `MediumFlexibleTopAppBar`, `LargeFlexibleTopAppBar`, `TwoRowsTopAppBar` | `m3e-app-bar size="small\|medium\|large"` |
| sliders (blog) | `Slider` with expressive `SliderDefaults` | `m3e-slider` |

**The 7 tactics and 4 expressive styles are candidates too.** They carry no component but
they change the most pixels: shapes, rich and nuanced color, emphasized typography, containment
for emphasis, fluid motion, component flexibility for foldables and large screens, and one or
two hero moments. Put them in the same round as the components, with the guide's own cautions
beside them (a smaller shape can make an essential action look unimportant; without contrast,
elements blend together).

## Phase 3 — One selection round

Build the ledger, copy the page, serve it, and let the user choose. The page is
`assets/selection.html` (self-contained: inline CSS and script, the M3E bundle from a CDN);
the ledger is `assets/ledger.example.json` as the shape reference.

### The ledger

```jsonc
{
  "app": { "name": "…", "package": "…", "round": 1, "title": "…", "sub": "…" },
  "transport": { "mode": "bridge|collector|copy", "submitUrl": "…", "shotsDir": "…", "answerIds": "position" },
  "screens":  [ { "id": "s1", "label": "Library", "route": "library", "reach": "first screen", "shot": "data:image/png;base64,…" } ],
  "decisions": [ {
    "id": "f1",                 // readable; the page turns it into a submission key
    "title": "…", "family": "button-group", "tactic": "6. leverage component flexibility",
    "body": "…",                 // blank line = new paragraph
    "recommendation": "apply|prototype|defer|skip",
    "variants": ["standard", "connected"],   // optional; the choice set the user picks from
    "kotlin": { "api": "…", "imports": "…", "optIn": "ExperimentalMaterial3ExpressiveApi" },
    "catalog": { "path": "components/buttongroup/ButtonGroupComposable.kt", "url": "https://…" },
    "current": "app/library/ListControls.kt:88-104 — three ToggleButtons",
    "screens": ["s1"], "effort": "S", "risk": "low", "dependsOn": ["f3"], "evidence": "3 production call sites",
    "preview": "<m3e-button-group variant=\"connected\">…</m3e-button-group>",   // live preview
    "previewShot": "data:image/png;base64,…"                                    // optional offline image
  } ]
}
```

Per decision the page offers **apply / prototype / defer / skip**, the `variants` as toggles,
and a note box; it answers every decision as `CHOICE | variant=… | note: …`. The submission
key is the decision id, except with `"answerIds": "position"` (the bridge transport), where the
page writes `q1 … qN` in decision order. Escape any `</script` inside a JSON string as
`<\/script`, or the page script ends early.

### Transport 1 — the session bridge (preferred)

The page rides the session's own loopback bridge, so the submit **arrives as the next user
message** with no polling and no extra process. Measured on 2026-09-21 from the extension
source and proved end to end (see Verification):

1. Call `grill_form` with **one question per decision, in ledger order**, and `open: false`.
   The tool declares its own ids: the round's questions are always `q1 … qN`, because the
   schema strips any `id` the caller sends (measured 2026-09-21: `data/round-1.json` held
   `["q1","q2"]` for a two-question round). Pass the decisions in the same order as the ledger
   and let the page key the payload by position.
2. Read the tool result: the page URL `http://127.0.0.1:<port>/g/<token>/round/<n>` and
   `Environment: <dir>` (a `<tmpdir>/omp-html-env-*` folder).
3. Copy `assets/selection.html` to `<dir>/public/m3e-selection.html` with the ledger inlined,
   and set `"transport": {"mode": "bridge", "answerIds": "position", "submitUrl": "http://127.0.0.1:<port>/g/<token>/round/<n>/answers"}`.
4. Open `<base>/env/m3e-selection.html` (`xdg-open`). Every file under `public/` is served at
   `/g/<token>/env/<name>`, so the page and its screenshots can sit next to the round data.
5. Submit POSTs `{"answers": {"q1": "APPLY | variant=connected", …}, "extra": ""}` to
   `<base>/round/<n>/answers`, which writes `data/answers-<n>.json` and injects one message
   into the session. End the turn before the submit; the answer message starts the next one.

`skill://grill-me-html` describes the tool; `skill://omp-live-session-rpc-testing` has the
harness to prove the round trip.

### Transport 2 — the collector (screenshots, or no grill_form)

```bash
nix shell nixpkgs#deno -c deno run -A assets/collector.ts <dir> --port 8765
```

It prints `M3E-COLLECTOR http://127.0.0.1:8765/` and
`M3E-COLLECTOR-ANSWER-ENDPOINT …/api/submit`. The ledger then reads
`"transport": {"mode": "collector", "submitUrl": "/api/submit", "shotsDir": "<dir>/shots"}`
(no `answerIds`: the collector copies the payload through, so the page uses the decision ids).
The user drops screenshots straight into the page; each one POSTs to `/api/shot?name=<id>`,
lands as `<dir>/shots/<id>.png`, and prints `M3E-SHOT <id> <bytes>`. The submit writes
`<dir>/answers.json` and prints `M3E-SUBMIT <path> (<n> decisions answered)`. Poll
`GET /api/state` for `{shots, answered, answers}`, wait for the file with a long-lived
background command (`timeout: 0`), or read it when the user says the round is done.

### Transport 3 — copy and paste

`"mode": "copy"` needs no endpoint. The submit shows the answers JSON in a box with a copy
button, and the user pastes it into the session. Use it when the page is opened from another
machine, and as the fallback when a fetch fails.

### Ledger honesty rules

- One decision per question. A compound decision produces an unusable answer.
- The preview markup must use the verified element and attribute names above. A wrong
  attribute is silently ignored — `m3e-shape name="cookie-4"` renders a plain square, because
  only the 35 library names exist (`square`, `4-sided-cookie`, `flower`, `gem`, `sunny`, …).
- Every candidate names a screen that exists in `screens`, and `screens` holds one row per
  destination of phase 1, including the ones with no capture.
- No candidate without `file:line` evidence or a catalog path.

## Phase 4 — The plan

Turn the answers into one plan, one row per decision: the choice, the screens, the API, the
file to change, and the check that proves it. Order the rows by `dependsOn`; prototype rows
become a throwaway branch with a decision, not a half-built feature. When the repository has a
remote, route every issue and PR body through the `issue-scribe` agent, and keep one issue per
row (or one stacked pair when two rows share a file).

The rework's own proof is phase 1 repeated: build, install, and capture the **same
destination list**, then compare each pair. Screens that the rework changed must show the
change; screens it did not touch must not change.

## Traps

- **The preview bundle is a network import.** `https://cdn.jsdelivr.net/npm/@m3e/web@2.8.2/dist/all.min.js`
  is the pinned entry (CORS `*`, verified 2026-09-21). When it does not load, the page shows a
  warning banner and the preview bodies stay empty; inline a `previewShot` for the candidates
  that matter, or capture the previews with `agent_browser_*` and inline those.
- **Do not restyle the page from scratch.** It already carries the selection controls, the
  progress counter, the zoom view and the three transports. Change the ledger, not the page.
- **The bridge owns its answer keys.** `grill_form` accepts no `id` per question, so the keys
  are always `q1 … qN` in the order you passed them, and `handleSubmit` drops anything the
  round does not own without an error. Pass one question per decision, in ledger order, and set
  `"answerIds": "position"`.
- **`hub start` fails when the omp broker is down** (`connect ENOENT …/broker.sock`). Start the
  collector with `setsid nohup … &` and read its log for the URL.
- **Deno, Node and Python are not on PATH on this host.** Every runtime comes from
  `nix shell nixpkgs#…`.
- **Verify with a real browser, not by reading the HTML.** `skill://verify-generated-html-artifact`
  has the computed-value checks; `skill://sandboxed-ui-verification` has the no-server and
  broker-down recipes.

## Verification

Prove the three load-bearing pieces before you hand the round to the user.

1. **The page renders and the guard upgrades** (`agent_browser_*` MCP tools):

```js
(() => {
  const cards = document.querySelectorAll(".card").length;
  const previews = Array.from(document.querySelectorAll(".preview-body"))
    .map((host) => host.firstElementChild
      ? host.firstElementChild.tagName + (host.firstElementChild.shadowRoot ? ":upgraded" : ":bare")
      : "empty");
  const theme = document.querySelector("m3e-theme");
  return JSON.stringify({
    m3e: document.body.dataset.m3e, cards, previews,
    screens: document.querySelectorAll(".screen").length,
    pickers: document.querySelectorAll('.screen input[type="file"]').length,
    ready: customElements.get("m3e-button") !== undefined,
    primary: theme ? getComputedStyle(theme).getPropertyValue("--md-sys-color-primary").trim() : null,
  });
})()
```

`data-m3e="ready"`, one card per decision, and `--md-sys-color-primary` equal to the color the
ledger set.

2. **The submit reaches the session.** Post one payload with `curl` and confirm the answers
   become the next user message:

```bash
curl -sS -X POST <base>/round/1/answers -H 'content-type: application/json' \
  -d '{"answers":{"q1":"APPLY | variant=connected"},"extra":""}'   # -> {"ok":true,"answers":1}
```

   With the collector, the same check reads `<dir>/answers.json`, and `GET /api/state` answers
   `{"ok":true,"shots":[…],"answered":true,"answers":{…}}`.

3. **The skill resolves**: `omp read skill://m3e-app-rework` prints this file.

Measured 2026-09-21 on NIXPC, so the shape of both outcomes is known before the round runs:

| Check | Result |
| --- | --- |
| fixture page over `http://127.0.0.1:8765/` | `data-m3e="ready"`, 6 cards, 3 screen rows (2 images, 1 picker), 5 previews upgraded, `--md-sys-color-primary` `#6750a4` |
| selection + submit (collector) | progress `6 / 6 decided`, result box "Submitted — the answers are now the next message in the session.", `answers.json` written, `M3E-SUBMIT … (6 decisions answered)` |
| screenshot upload from the page | `M3E-SHOT s3 70 bytes (2 captures)`, `/shots/s3.png` served as `image/png` |
| bridge, live session over RPC | `grill_form` round 1 URL and `Environment: /tmp/omp-html-env-*`; round ids `["q1","q2"]`; a custom page under `public/` served at `<base>/env/m3e-selection.html` (200); POST `<base>/round/1/answers` → `{"ok":true,"answers":2}`; the marker text arrived in the next user message |
| bridge keys by position | `"answerIds":"position"` turned six decisions into `q1 … q6` in decision order |

## Related skills

- `skill://material-design-3-ui` — the M3 design rules behind the tactics.
- `skill://compose-m3-expressive-migration-recon`, `skill://compose-m3e-migration-grounding` —
  the facts that gate the migration.
- `skill://nixos-agp-emulator-screenshot-loop`, `skill://android-emulator-screenshot-state-seeding` —
  build, boot, seed, capture.
- `skill://grill-me-html`, `skill://omp-live-session-rpc-testing` — the form bridge and its proof.
- `skill://show-html`, `skill://verify-generated-html-artifact`, `skill://sandboxed-ui-verification`,
  `skill://omp-html-page-tailnet-access` — page authoring, proof, and phone access.
