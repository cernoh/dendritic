---
name: compose-m3-expressive-migration-recon
description: "Gather the facts that gate a whole-app Material 3 Expressive migration in any Jetpack Compose repo before planning: whether the theme is already expressive, the BOM-to-material3 mapping, an expressive/adaptive API census, upstream work by gh search, the host's emulator capability, and reference-catalog stack mismatches. Use when asked to convert an app to Material 3 Expressive, to plan an M3E sweep, or to answer \"what does this migration actually touch\"."
---

# Recon before an M3 Expressive migration

Recon is all read-only, and it fits in one scout dispatch plus a few direct checks.
Never start planning before these six answers exist.

## 1. Is the theme already expressive?

Read the single theme entry point, then grep:

```
grep -n "MaterialExpressiveTheme\|MaterialTheme(\|dynamicColorScheme" <theme file>
grep -rn "MaterialExpressiveTheme\|DynamicMaterialExpressiveTheme" <src>
```

Forks are often **half-migrated**: `MaterialExpressiveTheme` already wraps the app, the
colour layer feeds it (`com.materialkolor`), and every component above it is still stock
M3. Then "switch to M3E" is NOT a theme task — it is a component and layout task, and the
plan changes completely.

Also read the history for a **partial revert**: `git log --oneline -i --grep=expressive`
plus `git show <sha>` on any revert. A "Revert part of Switch to MaterialExpressiveTheme"
commit is usually a preference-default rollback, not a rejection of the theme. Its diff
tells you which knobs the maintainers already fought over (palette style defaults, pref
keys) — those are the ones users will argue about again.

## 2. What material3 version does the pinned BOM actually resolve, and is the API stable?

The BOM mapping docs page lags. Read the BOM's own POM:

```
curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom \
  | grep -A2 "material3"
```

This prints the pinned `material3`, `material3-window-size-class`,
`material3-adaptive-navigation-suite` versions in one shot. A stable `material3` (for
example 1.4.0) can still carry `@ExperimentalMaterial3ExpressiveApi` on individual
components.

**Stability proof from the code, not the release notes:** if the repo already calls
`MaterialExpressiveTheme` with no `@OptIn`, the core expressive theme is stable at the
pinned version. Anything that needs an opt-in is a per-API question.

## 3. Census the surfaces

```
grep -rn "ExperimentalMaterial3ExpressiveApi\|MaterialShapes\|MotionScheme\|LoadingIndicator\|WavyProgress" <src>
grep -rn "WindowSizeClass\|currentWindowAdaptiveInfo\|NavigationSuiteScaffold\|ListDetailPaneScaffold" <src>
grep -rn "TopAppBar(\|NavigationBar(\|NavigationRail(\|ModalBottomSheet(\|FloatingActionButton(\|Card(\|SegmentedButton" <src>
```

All-zero on the first two greps means greenfield: no expressive or adaptive work has ever
landed, so there is nothing to reconcile, only to add. Then find how the navigation form is
chosen today — an orientation heuristic (`isTabletUi()`) is the common substitute for a
window size class, and replacing it is a small, high-value first step.

Find the shell and the action surfaces: the bottom nav lives with the top-level
destinations, and the biggest migrateable control is usually a hand-rolled bottom action
menu on the detail screen (floating toolbar / split button / button group candidates).

## 4. Did anyone upstream already do this?

```
gh pr list --repo <upstream> --search expressive --state all --limit 30
gh search commits --repo <upstream> "expressive"
```

An upstream theme-only commit means **nothing to cherry-pick**; say so explicitly in the
plan instead of letting the reader assume a merge will do the work.

## 5. Can this host even see the result?

```
which java adb emulator; echo "$ANDROID_HOME"
ls local.properties ~/.android/avd ~/.gradle 2>/dev/null
ls -d /nix/store/*androidsdk* /nix/store/*android-sdk-system-image*
```

An AVD directory or a leftover `modem-nv-ram-5554` proves an emulator has run here before;
a system-image derivation in the store proves it can again. No JDK and no `local.properties`
means the build needs a dev shell first. This decides whether "screenshots on every PR" is
a plan or a fantasy — decide it before promising visual verification.

## 6. Is the reference catalog the same stack?

Compare against the repo under change: `minSdk` (a catalog at 31 vs an app at 26), DI
(Hilt vs custom/Injekt), navigation (Navigation 3 vs Voyager/whatever), BOM channel (alpha
vs stable), and whether the catalog ships whole flows or single-component screens.

A foreign stack plus demo screens means **reference only** — read the API shapes, write your
own wrappers. Vendoring adds a NOTICE burden and imports foreign DI/nav assumptions.

## Then interview, don't implement

Turn the facts into one round of decisions, most important first, each holding exactly one
decision: deliverable shape (foundation then per-area sweeps vs one campaign), adaptive
scope, expression intensity, fallback preference, experimental-API policy, upstream sync
posture (`// KMK`-style islands vs free edits in shared files), reference-vs-vendor, and the
verification bar. Every one of those has a cheap default and an expensive alternative; make
the cost explicit and let the owner choose.
