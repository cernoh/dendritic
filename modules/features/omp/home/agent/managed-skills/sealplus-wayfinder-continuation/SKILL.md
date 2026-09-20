---
name: sealplus-wayfinder-continuation
description: "Resume work on the two Sealplus wayfinder maps (video trimming, Material 3 Expressive redesign): repo landmarks, settled scope including the ticket #7 VideoClip Float contract, the queue-wipe migration rule, concurrent-session tracker hazards, and verification constraints on this host."
---

Use when a task touches `/mnt/2tb-ext4/Sealplus` or a charted wayfinder map there. Two maps were
charted on 2026-09-18; tickets have been resolved since by concurrent sessions, so re-read the map's
Decisions-so-far before acting, and never write a map body from a stale copy.

## The two maps

Both live on `cernoh/Sealplus` (fork of `MaheshTechnicals/Sealplus`, itself a fork of `JunkFood02/Seal`).
Issues were disabled on the fork and were enabled with `gh repo edit cernoh/Sealplus --enable-issues`.

- **#1 Sealplus video trimming, made usable** — original tickets plus follow-ups (#20, #21, #22, #24).
  Resolved: #2, #3, #4, #6, #7.
- **#19 Sealplus on Material 3 Expressive** — resolved #9, #10, #12; #23 (BOM 1.4.0 vs 1.5.0-alpha) open.
- Cross-map edge: #18 (redesign verification contract) is blocked by #6 (the trim map's provisioning task).
- Live view: `wayfinder_view` with `map: 1` or `map: 19`. Its counts are **repo-wide**, not per map; use
  `~/.omp/agent/scripts/wayfinder-frontier.sh cernoh/Sealplus` for the authoritative frontier.

## Settled scope (do not relitigate)

- Trimming means **time trimming**, not geometric frame crop. Frame crop is out of scope.
- Trimming happens **at download time only**, inside yt-dlp's ffmpeg pass.
- The redesign deletes the Gradient Dark theme and its XML duplicate; one colour system, dynamic colour on
  Android 12+, brand purple as the fallback seed, and the per-tool `ToolPalette` colour system.
- The repo's marketing **website** is out of scope; the README's visual claims are rewritten.
- Both maps **decide only**. Hand off with `skill://to-spec` → `skill://to-tickets` → `skill://implement`.

## The VideoClip / task-queue contract (ticket #7, decided 2026-09-20)

`VideoClip(val start: Float = 0f, val end: Float = 0f)` (`util/VideoInfo.kt:162-166`): unit stays **seconds**,
field names stay `start`/`end`. No version marker. Rule: a field of `Task`/`DownloadPreferences` keeps its name
and unit, a new field must carry a default. Argument becomes
`"*%.3f-%.3f".format(locale = Locale.US, it.start, it.end)` (`util/DownloadUtil.kt:1291-1295`), skipping ranges
with `end <= start`. Range stays on `DownloadPreferences` only — no `DownloadedVideoInfo` column, no Room bump.

**Why the shape is fragile — reuse this reasoning for any task-list change.** The only persisted shape holding a
clip is `Task.preferences.videoClips` under the MMKV key `task_list` (`util/PreferenceUtil.kt:557-566`). The
reader is `Json { ignoreUnknownKeys = true; allowStructuredMapKeys = true }` (`:313-315`), so a renamed field is
dropped and silently defaulted, not an error. A decode failure returns an **empty map**, and the writer collector
in `download/DownloaderV2.kt:255-280` then stores that empty map over the blob — a queue wipe, not a crash. Hence
no `require` in the persisted model.

Two supporting facts measured in the pinned library: kotlinx.serialization 1.11.0
(`gradle/libs.versions.toml:28`) decodes a JSON integer literal into a `Float` field — `decodeFloat()` is
`lexer.parseString("float") { toFloat() }` — so `"start": 12` loads as `12.0f`; and `Float` seconds keeps
sub-millisecond resolution to about an hour (ULP 0.24 ms at 2048 s, 0.98 ms at 8192 s).

Handed to #22: the clip file name must render both timestamps with sub-second precision; an index may join them,
not replace them. `CLIP_TIMESTAMP` (`util/DownloadUtil.kt:247`, used at `:253`) truncates via `%(section_start)d`
today. Also owed: the whole-second clamp `valueRange.toIntRange()` (`VideoSectionSlider.kt:201`,
`util/TextUtil.kt:71`) must compare in `Float` seconds.

## The Material 3 Expressive answer (ticket #9, decided)

Compose BOM `2026.05.01` resolves `androidx.compose.material3:material3` to **1.4.0**, which carries almost no
expressive API. Full report on branch `research/m3e-pinned-material3-api-surface`
(`research/pinned-material3-expressive-api-surface.md`, plus `research/evidence/material3-1.4.0-optin-dump.txt`).

- **Absent at 1.4.0:** `ButtonGroup`, `SplitButton`, `FloatingActionButtonMenu`, `LoadingIndicator`,
  `HorizontalFloatingToolbar`, `ToggleButton`, `MaterialShapes` (their `tokens/*` classes remain).
- **Present but Kotlin `internal`, so uncallable:** `MaterialExpressiveTheme`, `MaterialTheme.motionScheme`,
  `MotionScheme`, the 15 `*Emphasized` typography styles, `FlexibleBottomAppBar`. The sources jar is the
  authority; `javap` shows public and internal names are not reliably mangled.
- **Cause:** release note 1.4.0-beta01 removed every API tagged `ExperimentalMaterial3ExpressiveApi`; the marker
  exists at 1.4.0 as an `internal annotation class` referenced by no class.
- **Usable with no opt-in:** `ShortNavigationBar`, `WideNavigationRail` + `ModalWideNavigationRail`, stateless
  `Slider`/`RangeSlider`, `IconToggleButton`, `SegmentedButton`, `NavigationSuiteScaffold` (from
  `material3-adaptive-navigation-suite` 1.4.0).
- **Artifacts:** add `material3-adaptive-navigation-suite` 1.4.0 and, for panes,
  `adaptive`/`adaptive-layout`/`adaptive-navigation` 1.2.0. Do **not** add `graphics-shapes` (no
  `MaterialShapes`). `AdaptiveInfo` does not exist; the type is `WindowAdaptiveInfo`.
- #23 decides whether the effort holds at 1.4.0 or moves to 1.5.0-alpha, and blocks #13, #15, #16.
- Method for any follow-up artifact question: `skill://android-artifact-api-surface-forensics`.

## Repo landmarks

- All yt-dlp arguments: `app/src/main/java/com/junkfood/seal/util/DownloadUtil.kt` —
  `--download-sections` at :1292, clip output template `CLIP_TIMESTAMP` at :247, artwork-crop `--ppa` near :262
  written to a generated `--config` near :1031.
- Trim data model `VideoClip`: `util/VideoInfo.kt:161`. Trim UI: `ui/component/FormatItem.kt:227`,
  `ui/page/download/VideoSectionSlider.kt:161` (`VideoClipDialog`), state in
  `ui/page/downloadv2/configure/FormatPage.kt:616-623`, `:811`, `:1382`.
- Download history entity `database/objects/DownloadedVideoInfo.kt` (Room version 10, hand-written
  `MIGRATION_5_6 … 9_10` plus `fallbackToDestructiveMigration()` in `util/DatabaseUtil.kt:25-100`); the same
  entity is the JSON backup shape (`database/backup/Backup.kt`).
- Theme: `ui/theme/Theme.kt` (Gradient Dark override :66-91), `Shape.kt`, `Type.kt`, `ColorScheme.kt`
  (`DEFAULT_SEED_COLOR = 0xa3d48d`); `:color` module vendors `kyant/monet`.
- Navigation: `ui/page/AppEntry.kt` (drawer + NavHost), `ui/page/NavigationDrawer.kt:460-489`, `ui/common/Route.kt`.
- Two Material generations: `ui/component/ModalBottomSheetM2.kt` used by `TaskListPage`, `DownloadDialogV2`,
  `VideoListPage`, `VideoDetailDrawer`, `DownloadSettingsDialog`.
- Dead code for tier 1: `ui/component/PremiumComponents.kt`, `ui/integration/IntegrationExamples.kt`,
  `ui/page/settings/appearance/GradientDarkExample.kt`, unreferenced `res/anim/*.xml`.
- Size facts: ~33,000 lines across ~75 UI files; `NewHomePage.kt` ~2,700 lines, `FormatPage.kt` 1,902.
  `app/build.gradle.kts` declares the BOM plus the `androidxCompose` bundle; `minSdk 24`, `compileSdk`/`targetSdk`
  37, Java 21 toolchain, AGP 9.2.1, Kotlin 2.3.21, kotlinx.serialization 1.11.0.

## Verification constraints on this host

- `/dev/kvm` is world-writable, 16 cores, 31 GB RAM, **no display** → the emulator must run headless and
  screenshots come from `adb exec-out screencap -p`.
- The fork has Actions enabled but zero registered workflows and zero runs, despite `android_ci.yml` and
  `android.yml` being committed. Do not assume CI builds anything.
- `javap` needs `nix shell nixpkgs#jdk21`; `python3` is absent unless you go through nix.

## Traps that cost time

- `gh issue close` prints nothing on stdout; verify with `gh issue view <n> --json state,stateReason` before
  refreshing `wayfinder_view` or the frontier, otherwise a stale read makes a resolved ticket look open.
- Wire blocking edges in a **second pass** with issue database ids
  (`gh api repos/cernoh/Sealplus/issues/N --jq .id`); `issue_dependencies_summary` needs ~8 s to report a fresh
  edge, so sleep before running the frontier query.
- `grill_form` requires a `title` on **every** question; omitting it fails validation with the whole round
  returned.
- Parallel research agents: dispatch with `isolated: true` and forbid `git` inside them; the parent session
  commits their reports to one `research/*` branch and pushes it.
- Sub-issues: `gh api --method POST repos/cernoh/Sealplus/issues/<map>/sub_issues -F sub_issue_id=<child db id>`.
- The repo has no `user.email` configured; set it locally to `cernoh <cernoh@users.noreply.github.com>` to match
  the existing research-branch commits.
- Map bodies are edited by concurrent sessions: fetch the body immediately before writing, chain
  fetch → append → edit, and verify afterwards. Issue bodies have no recoverable history.
- Route issue prose through `issue-scribe` (Rule 7). Editing the map's one-line Decisions-so-far index
  mechanically in the session is fine; a resolution comment is not.
- Research branches stay on origin as the artifact home (`research/ticket-02-…`, `research/filmstrip-frames`,
  `research/m3e-pinned-material3-api-surface`); return the main checkout to `main` when the session ends.
