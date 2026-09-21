---
name: komikku-m3e-migration
description: "Implement or extend the Material 3 Expressive migration in the Komikku fork at /mnt/2tb-ext4/komikku-M3E (cernoh/komikku-M3E): the build shell and its aapt2 trap, the per-module material3 version pin, the m3e wrapper package, the i18n-kmk string rule, and the verification gates with their real timings."
---

# Komikku → Material 3 Expressive (komikku-M3E)

Use when working in `/mnt/2tb-ext4/komikku-M3E` (remote `cernoh/komikku-M3E`, a Komikku fork of Mihon + TachiyomiSY): adding expressive wrappers, migrating an area, or explaining why a component is still stock.

The confirmed design record lives at `/tmp/grilling-komikku-m3e.md` (37 decisions, 6 rounds). Read it before contradicting a settled choice: single expressive look, no new preferences, strict upstream posture, selective expression. Issue #1 + PR #4 are the foundation; issues #2 + PR #3 are the FlexibleAdapter dependency fix that lands first.

## Build

No `java`, no `android-sdk`, no `local.properties` on this host. `shell.nix` (added by the foundation PR) provides JDK 17, platform 36, build-tools 36.0.0 and 35.0.0.

```bash
GRADLE_USER_HOME=/mnt/2tb-ext4/.gradle-komikku nix-shell --run 'cd /mnt/2tb-ext4/komikku-M3E && ./gradlew <tasks> -Pandroid.aapt2FromMavenOverride=$AAPT2_OVERRIDE --console=plain'
```

- The repo asks for **build-tools 35.0.0** as well as 36.0.0; a shell with only 36 fails with "The SDK directory is not writable".
- AGP's own `aapt2` cannot run on NixOS. Always pass `-Pandroid.aapt2FromMavenOverride=$AAPT2_OVERRIDE`.
- Run long Gradle work as an async job with no tool deadline: the bash tool kills a foreground call at 900 s. `spotlessApply`/`spotlessCheck` over the `app` module took **16 minutes** on a cold cache and ~40 s once warm.
- Verify a "fast" build really compiled by checking class or APK mtimes, not just `BUILD SUCCESSFUL`: `app/build/tmp/kotlin-classes/debug/...` and `app/build/outputs/apk/debug/`.
- Gate order: `spotlessApply` → `spotlessCheck` → `assembleDebug`. Scope `spotlessApply` to the changed modules; keep the full `spotlessCheck` for the final check.

## Version pinning (the trap that bites first)

Every Compose module resolves its own graph: `configureCompose` in `buildSrc/.../ProjectExtensions.kt` adds `platform(compose.bom)` per module.

- `compose-bom` (any released version, including the newest) pins `material3 1.4.0`, where `MaterialExpressiveTheme` is **`internal`** and `ButtonGroup`, `FloatingToolbar`, `LoadingIndicator`, `MaterialShapes`, `SplitButton` and `WavyProgressIndicator` **do not exist**.
- `:app` escapes that only because `materialkolor` drags `androidx.compose.material3:material3` to `1.5.0-alpha14` through `org.jetbrains.compose.material3`. `:presentation-core` has no materialkolor.
- So the pin lives once in `gradle/compose.versions.toml` (`material3 = "1.5.0-alpha14"`) and `configureCompose` holds it with `add("implementation", compose.material3.core) { version { strictly(...) } }`. Note `constraints { implementation(...) }` does not resolve in buildSrc; use the `add` form.
- Class-name greps lie about Compose APIs. Settle existence from the **sources jar** of `material3-android-<version>` on Google Maven.

## Code conventions

- Wrappers live in `presentation-core/src/main/java/tachiyomi/presentation/core/components/m3e/` (new files only): floating toolbar + action, split button, navigation bar and wide rail, wavy progress, chips, `WindowSizeClass.kt`.
- Each wrapper carries its own `@file:OptIn(ExperimentalMaterial3ExpressiveApi::class)` (and `ExperimentalMaterial3ComponentOverrideApi` for `ShortNavigationBar`). Do not add module-wide opt-ins.
- Trailing lambdas bind to the **last** parameter: keep `content` last in wrapper signatures or the call sites fail with "Too many arguments".
- Thin shims may change in place; structural components become new composables. Keep `// KMK -->` / `// KMK <--` islands.
- New user-facing text is Komikku-only: `i18n-kmk/src/commonMain/moko-resources/base/strings.xml` with `KMR`. Never in `i18n/`, `i18n-sy/`, and never in a non-base locale.
- The app's own long-press components stay: `presentation-core/.../components/material/Surface.kt` and `Button.kt` carry `onLongClick`, which stock material3 chips and buttons do not.

## Landmarks

- Theme: `app/src/main/java/eu/kanade/presentation/theme/TachiyomiTheme.kt` (already `MaterialExpressiveTheme`).
- Shell: `app/src/main/java/eu/kanade/tachiyomi/ui/home/HomeScreen.kt`; the size class is provided in `app/src/main/java/eu/kanade/tachiyomi/util/view/ViewExtensions.kt`.
- `isTabletUi()` remains for the non-navigation call sites by decision.
- `FlexibleAdapter` comes from Maven Central (`eu.davidea:flexible-adapter:5.1.0`) because JitPack cannot rebuild the pinned fork commit.

## Delivery

Issues are enabled; issues and PR bodies are written by the `issue-scribe` agent in Simplified Technical English. PR titles end with their own `(#N)`. Stack children on the parent branch (`gh stack` v0.1.0 is installed). There is no emulator and no screenshot harness by decision, so the first visual check is a device install: state that plainly instead of implying visual verification.
