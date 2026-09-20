---
name: compose-material3-module-resolution-divergence
description: "Diagnose a multi-module Compose app where one module compiles against a different androidx material3 version than the app runs (per-module BOM platform + a KMP library pulling an alpha transitively), including the probe commands and the compile-valid/runtime-crash hazard"
---

# Compose material3 per-module resolution divergence

Use when a Compose app module cannot call an API that compiles fine elsewhere, when a wrapper
module sees a smaller material3 surface than the app, or before placing shared M3 wrappers in a
non-app module. Measured on Komikku (multi-module: `:app`, `:presentation-core`,
`:presentation-widget`, `:data`, …) with `compose-bom 2026.06.01`.

## The mechanism

`implementation(platform(compose.bom))` is applied **per module** (there, in
`buildSrc/.../ProjectExtensions.kt`, `configureCompose`). Each module therefore resolves the BOM's
versions independently. Gradle does not unify versions across projects, so:

- A module with only `platform(bom)` gets exactly the BOM's version — there, `material3 1.4.0`,
  where `MaterialExpressiveTheme` is **`internal`** (uncallable) and `ButtonGroup`,
  `FloatingToolbar`, `LoadingIndicator`, `MaterialShapes`, `SplitButton`, `WavyProgressIndicator`
  do not exist.
- A module that transitively pulls a higher version gets that one instead. There, only `:app` did,
  because it declared `com.materialkolor:material-kolor:5.0.0-alpha07` → `org.jetbrains.compose.material3:material3:1.11.0-alpha03`
  → `androidx.compose.material3:material3:1.5.0-alpha14`.

The same JB artifacts also move the rest of the stack: `org.jetbrains.compose.foundation:foundation:1.11.0-alpha03`
→ `androidx.compose.foundation:foundation:1.11.0-alpha05`, and likewise `ui`. So a single
dynamic-colour dependency can put the whole app's Compose stack above the BOM, silently.

**Hazard:** a wrapper module compiling against the BOM version while the app runs the alpha is
compile-valid and runtime-broken (`NoSuchMethodError` / `NoClassDefFoundError`) the moment the
wrapper calls an API that exists only in the alpha. Fix by declaring the pin in **every** module
that compiles against those APIs, not only in the app.

The opt-in flag is per module too: `-opt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi`
in `:app` does nothing for `:presentation-core`. Prefer per-file `@OptIn` inside the wrapper
package — greppable, and it survives module moves.

## Probes (no JDK, no Gradle run required)

1. **Which modules declare what.** Search all build files for the library and the BOM:
   `materialKolor|compose\.material3|compose\.bom` over `**/build.gradle.kts`. The module that
   declares the KMP library is the only one that escapes the BOM.
2. **What the convention plugin injects.** Read the `configureCompose`-style helper; a
   `platform(bom)` there means every Compose module is constrained independently.
3. **True transitive version of a KMP library — read Gradle module metadata, not the POM:**
   `https://repo1.maven.org/maven2/<group-path>/<artifact>/<ver>/<artifact>-<ver>.module`,
   then `jq -r '.variants[] | select(.name=="<variant>ApiElements-published") | (.dependencies // [])[] | "\(.group):\(.module) -> \(.version.requires)"'`.
   Do this for each hop (`materialkolor` → JB `material3` → androidx `material3`).
4. **What an artifact really exposes — sources jar, never class-name greps.**
   `https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/<ver>/material3-android-<ver>-sources.jar`,
   then `unzip -o -q … -d src` and grep the `.kt` files. Class-name greps lie both ways: a
   composable usually has no class of its own (`FlexibleBottomAppBar` is a function in `AppBar.kt`),
   and `MaterialExpressiveTheme` in 1.4.0 shows up only as a synthetic
   `MaterialThemeKt$MaterialExpressiveTheme$1.class` while the function itself is `internal`.
5. **Prove the resolved version empirically** when a build is possible: a symbol that compiles in
   one module and not another is the resolution difference made visible.
6. **Check for a stable escape hatch before promising one:** the library's `maven-metadata.xml`
   version list. There, the newest BOM (`2026.09.00`) still pinned `material3 1.4.0`, and the
   newest published line was `1.5.0-alpha28` — no stable route to the expressive components.

## Reporting

State per module: resolved material3 version, the dependency that sets it, which expressive APIs
are therefore callable, and whether the module carries the opt-in. A single "the app uses
material3 X" headline hides exactly the bug this skill exists to catch.
