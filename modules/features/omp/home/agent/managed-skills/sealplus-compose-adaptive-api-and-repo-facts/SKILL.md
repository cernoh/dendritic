---
name: sealplus-compose-adaptive-api-and-repo-facts
description: "Measured facts for adaptive/multi-pane layout work in the Sealplus Android repo (cernoh/Sealplus, Compose BOM 2026.05.01): what the pinned adaptive artifacts actually expose and need opt-in, the width breakpoints, the lack of any Navigation 2 integration, and the repo's real window-size touchpoints (including the dead two-column download-history code). Use when deciding or implementing adaptive layout, panes, or width-class behaviour in Sealplus, or before re-measuring these artifacts."
---

# Pinned Compose adaptive surface (BOM 2026.05.01 → material3 1.4.0)

Resolved from the BOM POM, then AAR + `-sources.jar` (Kotlin visibility) + `javap -v` (opt-in markers).
Method for a fresh measurement: `skill://android-artifact-api-surface-forensics`.

| coordinate | version | note |
|---|---|---|
| `androidx.compose.material3.adaptive:adaptive` | 1.2.0 | provides `currentWindowAdaptiveInfo()` |
| `...adaptive:adaptive-layout` | 1.2.0 | pane scaffolds |
| `...adaptive:adaptive-navigation` | 1.2.0 | navigators + `Navigable*PaneScaffold` |
| `androidx.compose.material3:material3-adaptive-navigation-suite` | 1.4.0 | separate artifact, not inside material3 |
| `androidx.compose.material3.adaptive:adaptive-navigation3` | **not in BOM; no 1.2.0 exists** | ladder: 1.0.0-alpha0x, 1.3.0-alpha0x…1.3.0, 1.4.0-alpha0x |
| `androidx.window:window-core` | 1.4.0 transitive | owns the real `WindowSizeClass` |

## Present and cheap (no opt-in)

- `currentWindowAdaptiveInfo(supportLargeAndXLargeWidth: Boolean = false): WindowAdaptiveInfo` — public, no opt-in.
- `WindowAdaptiveInfo.windowSizeClass` is `androidx.window.core.layout.WindowSizeClass`, breakpoints
  medium 600dp, expanded 840dp, height 480dp/900dp. No `Large`/`ExtraLarge` constants at window-core 1.4.0.
- `ThreePaneScaffoldRole` (`Primary`, `Secondary`, `Tertiary`), `PaneScaffoldRole`, `PaneScaffoldDirective`.
- `NavigationSuiteScaffold`, `NavigationSuiteType`, and `NavigationSuiteScaffoldDefaults.navigationSuiteType(adaptiveInfo)`.
  There is **no** `calculateNavigationSuiteType` symbol.

## Present but needing `@OptIn(ExperimentalMaterial3AdaptiveApi::class)`

`androidx.compose.material3.adaptive.ExperimentalMaterial3AdaptiveApi`, `@RequiresOptIn`, BINARY retention.

`ListDetailPaneScaffold`, `SupportingPaneScaffold`, `NavigableListDetailPaneScaffold`,
`NavigableSupportingPaneScaffold`, `rememberListDetailPaneScaffoldNavigator`,
`rememberSupportingPaneScaffoldNavigator`, `calculatePaneScaffoldDirective` (+
`calculatePaneScaffoldDirectiveWithTwoPanesOnMediumWidth`), `calculateThreePaneScaffoldValue`,
`ThreePaneScaffoldState`/`MutableThreePaneScaffoldState`, `ThreePaneScaffoldValue` (class carries the marker,
constructor is `internal`), `AnimatedPane` (needs a pane scope), `ThreePaneScaffoldPredictiveBackHandler`.

`ExperimentalMaterial3AdaptiveComponentOverrideApi` gates only the pane-override extension point.
`ExperimentalMaterial3AdaptiveNavigationSuiteApi` gates **nothing** at 1.4.0 — the suite needs no opt-in.

## Pane thresholds at 1.2.0

`calculatePaneScaffoldDirective`: 1 horizontal partition below 840dp (compact and medium), 2 at expanded
(840dp, 24dp spacer), 3 only for large/extra-large (1200/1600) and only reachable when
`currentWindowAdaptiveInfo(supportLargeAndXLargeWidth = true)`. With the default flag the size class can only
be 0/600/840, so 3-pane layouts are unreachable.

## Navigation library

`adaptive-layout` and `adaptive-navigation` 1.2.0 have **zero** `androidx.navigation` or navigation3
dependencies: pane scaffolds work in a Navigation-Compose 2.x `NavHost` app (the app drives the navigator
itself). There is **no** Nav2 integration type at 1.2.0 — no `NavHost`-shaped helper, no
`NavController`-based scaffold. Only `adaptive-navigation3` (1.3.0, needs `navigation3-ui:1.0.0`) provides
`ListDetailSceneStrategy`/`SupportingPaneSceneStrategy`.

Also: `androidx.window.core.layout.WindowWidthSizeClass` is `@Deprecated`; the legacy
`androidx.compose.material3.windowsizeclass.*` types are not, but their factories need
`@OptIn(ExperimentalMaterial3WindowSizeClassApi::class)`.

# Repo facts that decide adaptive work (Sealplus, branch main, measured 2026-09-20)

- The only window-size machinery today: `calculateWindowSizeClass(activity)` at `MainActivity.kt:59` and
  `QuickDownloadActivity.kt:89`, published as `LocalWindowWidthState` (`ui/common/CompositionLocals.kt:26`,
  a `staticCompositionLocalOf` fed once per activity creation by `SettingsProvider`), read at ~6 call sites
  (drawer mode, legacy `DownloadPage` dialog choice, home header, FAB, queue-item weight). No
  `WindowAdaptiveInfo`, no adaptive imports, one `BoxWithConstraints`, no `onConfigurationChanged` overrides.
- `NavigationDrawer.kt:105-131`: Compact/Medium → modal drawer; Expanded → 92dp rail **plus** the same modal
  drawer. `NavigationDrawer.kt:580-582` re-derives classes from raw dp with wrong thresholds (480/360) in a
  private preview.
- The download-history "two-column grid at expanded widths" is **dead code**: `VideoListPage.kt:448-453`
  computes `cellCount`/`span` and the container is a `LazyColumn` (:454); `span` is never referenced.
- `MainActivity` declares only `android:configChanges="orientation"` (manifest :125): rotation does not
  recreate it, a multi-window resize does (screenSize absent); `onResume` also calls `recreate()` when
  returning with auth needed.
- Selection state is plain `remember` in `VideoListPage.kt:168,200`, `VideoInfoDownloadPage`,
  `CommentDownloadPage`; `DownloadDialogViewModel`, `VideoListViewModel`, the three tool view models and
  `CookiesViewModel` survive config changes. `rememberLazyListState` already preserves scroll.
- Grids that adapt to content: `MoreToolsPage.kt:183` `GridCells.Adaptive(176.dp)`, `FormatPage.kt:851`
  `Fixed(1)`/`Adaptive(160.dp)`, `DownloadPageV2.kt:475` `Adaptive(240.dp)`. Fixed and window-blind:
  `VideoInfoDownloadPage.kt:288`, `CommentDownloadPage.kt:288` (`Fixed(2)`), `SponsorPage.kt:182` (`Fixed(12)`).
- 46 `Scaffold` call sites (41 in `ui/page`, 4 previews in `ui/integration/IntegrationExamples.kt`, 1 in
  `CrashReportActivity`). Sheet wrappers: `SealModalBottomSheet` (M3) 8 real call sites, `SealModalBottomSheetM2`
  4, `SealModalBottomSheetM2Variant` 2, plus raw M3 sheets in `NewHomePage.kt:1869,2163`. Every sheet is
  modal and rooted where it is emitted, so it covers the pane that launched it.
- The settings graph `AppEntry.kt:302-393` holds 25 distinct destinations behind `Route.SETTINGS`; the root
  list has 12 `PreferenceItem`s; sub-pages share `BasePreferencePage.kt:46` and push rather than pane.
- Tool detail pairs are pushed destinations: `VIDEO_INFO_DOWNLOAD` → `VIDEO_INFO_DETAIL`,
  `COMMENT_DOWNLOAD` → `COMMENT_DETAIL`; `BatchUrlImportPage` and `ThumbnailDownloadPage` have no detail.
  The task log is its own destination (`TASK_LOG arg TASK_HASHCODE` → `command/TaskLogPage.kt`).
- Overlays (splash, onboarding, lock screen, crash report, `QuickDownloadActivity`) read no width class;
  `CrashReportActivity.kt:40` hardcodes `WindowWidthSizeClass.Compact`.
