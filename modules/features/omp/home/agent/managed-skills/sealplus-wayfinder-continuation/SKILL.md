---
name: sealplus-wayfinder-continuation
description: "Resume work on the two Sealplus wayfinder maps (video trimming, Material 3 Expressive redesign): repo landmarks, settled scope including the decided Material 3 1.4.0 expressive-API answer, concurrent-session tracker hazards, and verification constraints on this host."
---

# Sealplus wayfinder continuation

Use when a task touches `/mnt/2tb-ext4/Sealplus` or a charted wayfinder map there. Two maps were
charted on 2026-09-18; several tickets were resolved the same day by concurrent sessions, so
re-read the map's Decisions-so-far before acting, and never write a map body from a stale copy.

## The two maps

Both live on `cernoh/Sealplus` (fork of `MaheshTechnicals/Sealplus`, itself a fork of `JunkFood02/Seal`).
Issues were disabled on the fork and were enabled with `gh repo edit cernoh/Sealplus --enable-issues`.

- **#1 Sealplus video trimming, made usable** — 7 original tickets plus follow-ups (#21, #22, #24).
- **#19 Sealplus on Material 3 Expressive** — 10 original tickets plus #23. Resolved by
  2026-09-18 evening: #9 (API surface), #10 (Material Symbols), #12 (migration plan).
- Cross-map edge: #18 (redesign verification contract) is blocked by #6 (the trim map's
  provisioning task) — one repo, so a blocker from the other map is wired normally.
- Live view: `wayfinder_view` with `map: 1` or `map: 19`. Its counts are **repo-wide**, not per
  map; use `~/.omp/agent/scripts/wayfinder-frontier.sh cernoh/Sealplus` for the authoritative
  frontier.

## Settled scope (do not relitigate)

- Trimming means **time trimming**, not geometric frame crop. Frame crop is out of scope.
- Trimming happens **at download time only**, inside yt-dlp's ffmpeg pass.
- The redesign deletes the Gradient Dark theme and its XML duplicate; one colour system, dynamic
  colour on Android 12+, brand purple as the fallback seed.
- The redesign deletes the per-tool `ToolPalette` colour system; tool identity moves to
  containment, shape and icon on Material roles.
- The repo's marketing **website** is out of scope; the README's visual claims are rewritten.
- Both maps **decide only**. Hand off with `skill://to-spec` → `skill://to-tickets` → `skill://implement`.

## The Material 3 Expressive answer (ticket #9, decided)

Compose BOM `2026.05.01` resolves `androidx.compose.material3:material3` to **1.4.0**, which
carries almost no expressive API. Full report on branch `research/m3e-pinned-material3-api-surface`
(`research/pinned-material3-expressive-api-surface.md`, plus
`research/evidence/material3-1.4.0-optin-dump.txt`).

- **Absent at 1.4.0:** `ButtonGroup`, `SplitButton`, `FloatingActionButtonMenu`, `LoadingIndicator`,
  `HorizontalFloatingToolbar`, `ToggleButton`, `MaterialShapes`. Their `tokens/*` classes remain.
- **Present but Kotlin `internal`, so uncallable:** `MaterialExpressiveTheme`,
  `MaterialTheme.motionScheme`, `MotionScheme`, the 15 `*Emphasized` typography styles,
  `FlexibleBottomAppBar`. The sources jar is the authority; `javap` shows these public and
  internal names are not reliably mangled.
- **Cause:** release note 1.4.0-beta01 removed every API tagged `ExperimentalMaterial3ExpressiveApi`
  or `ExperimentalMaterial3ComponentOverrideApi` and pointed at 1.5.0-alpha. The marker exists at
  1.4.0 as an `internal annotation class` referenced by no class in the artifact.
- **Usable with no opt-in:** `ShortNavigationBar`, `WideNavigationRail` + `ModalWideNavigationRail`,
  stateless `Slider`/`RangeSlider`, `IconToggleButton` family, `SegmentedButton`, and
  `NavigationSuiteScaffold` from `material3-adaptive-navigation-suite` 1.4.0.
- **Artifacts:** add `material3-adaptive-navigation-suite` (1.4.0) and, if panes are wanted,
  `adaptive`/`adaptive-layout`/`adaptive-navigation` (1.2.0, `ExperimentalMaterial3AdaptiveApi`).
  Do **not** add `graphics-shapes`: not a `material3` 1.4.0 dependency, and it has no `MaterialShapes`.
  `AdaptiveInfo` does not exist; the type is `WindowAdaptiveInfo`.
- Consequence: [#23](https://github.com/cernoh/Sealplus/issues/23) decides whether the effort
  holds at 1.4.0 or moves to 1.5.0-alpha, and it blocks #13, #15 and #16. The map Destination's
  "library motion and shape" claim waits on that decision.
- Method for any follow-up artifact question: `skill://android-artifact-api-surface-forensics`.

## Repo landmarks

- All yt-dlp arguments: `app/src/main/java/com/junkfood/seal/util/DownloadUtil.kt` —
  `--download-sections` at :1292, clip output template near :247, artwork-crop `--ppa` near :262
  written to a generated `--config` near :1031.
- Trim data model `VideoClip(start: Int, end: Int)`: `util/VideoInfo.kt:161`.
- Trim UI today: `ui/component/FormatItem.kt:227`, `ui/page/download/VideoSectionSlider.kt:161`
  (`VideoClipDialog`), state in `ui/page/downloadv2/configure/FormatPage.kt:616-623`.
- Theme: `ui/theme/Theme.kt` (Gradient Dark override :66-91), `Shape.kt` (`Shapes = Shapes()`),
  `Type.kt` (stock), `ColorScheme.kt` (`DEFAULT_SEED_COLOR = 0xa3d48d`); `:color` module vendors
  `kyant/monet`.
- Navigation: `ui/page/AppEntry.kt` (drawer + NavHost), `ui/page/NavigationDrawer.kt:460-489`
  (hand-rolled rail), `ui/common/Route.kt` (36 string routes).
- Two Material generations: `ui/component/ModalBottomSheetM2.kt` used by `TaskListPage`,
  `DownloadDialogV2`, `VideoListPage`, `VideoDetailDrawer`, `DownloadSettingsDialog`.
- Dead code for tier 1: `ui/component/PremiumComponents.kt`, `ui/integration/IntegrationExamples.kt`,
  `ui/page/settings/appearance/GradientDarkExample.kt`, unreferenced `res/anim/*.xml`.
- Size facts: ~33,000 lines across ~75 UI files; `NewHomePage.kt` ~2,700 lines, `FormatPage.kt`
  1,902, `DownloadDialogV2.kt` ~1,250; 44 `Scaffold` sites; ~78 files import
  `material-icons-extended`; no tests beyond two placeholders.
- `app/build.gradle.kts` declares the BOM plus the `androidxCompose` bundle and
  `material3-window-size-class`; `minSdk 24`, `compileSdk`/`targetSdk` 37, Java 21 toolchain,
  AGP 9.2.1, Kotlin 2.3.21; `nix` is available and no JDK or Android SDK is installed.

## Verification constraints on this host

- `/dev/kvm` is world-writable, 16 cores, 31 GB RAM, **no display** → the emulator must run
  headless and screenshots come from `adb exec-out screencap -p`.
- The fork has Actions enabled but zero registered workflows and zero runs, despite
  `android_ci.yml` and `android.yml` being committed. Do not assume CI builds anything.
- `javap` needs `nix shell nixpkgs#jdk21`; `python3` is absent unless you go through nix.

## Traps that cost time

- Wire blocking edges in a **second pass** with issue database ids
  (`gh api repos/cernoh/Sealplus/issues/N --jq .id`); `issue_dependencies_summary` needs ~8 s to
  report a fresh edge, so sleep before running the frontier query.
- `grill_form` requires a `title` on **every** question; omitting it fails validation with the
  whole round returned.
- Parallel research agents: dispatch with `isolated: true` and forbid `git` inside them; the
  parent session commits their reports to one `research/*` branch and pushes it.
- Sub-issues: `gh api --method POST repos/cernoh/Sealplus/issues/<map>/sub_issues -F sub_issue_id=<child db id>`.
- The repo has no `user.email` configured; set it locally to
  `cernoh <cernoh@users.noreply.github.com>` to match the existing research-branch commits.
- Map bodies are edited by concurrent sessions: fetch the body immediately before writing,
  chain fetch → append → edit, and verify afterwards. Issue bodies have no recoverable history.
- Research branches stay on origin as the artifact home (`research/ticket-02-…`,
  `research/filmstrip-frames`, `research/m3e-pinned-material3-api-surface`); return the main
  checkout to `main` when the session ends.
