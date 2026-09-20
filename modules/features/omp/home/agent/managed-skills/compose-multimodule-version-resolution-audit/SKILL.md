---
name: compose-multimodule-version-resolution-audit
description: "Audit which androidx.compose version each module of a multi-module Android app really compiles against, when a transitive library (e.g. materialkolor) lifts one module above the BOM and splits the app; includes the probe commands, the compile-vs-runtime hazard, and the authoritative-pin fix."
---

# Compose multi-module version resolution audit

Use before adding a component library, migrating to a new material3 line, or planning an
expressive/Material 3 component sweep in a multi-module Compose app. The failure this prevents:
code that compiles in module A against version X and runs in module B against version Y.

## The trap

A version catalog entry with **no version** (`material3-core = { module = "androidx.compose.material3:material3" }`)
resolves from whatever BOM platform the module applies. Convention plugins usually add
`implementation(platform(compose.bom))` **per module**, so every module resolves the BOM's
version independently, and a transitive dependency declared in only one module can lift that
module's resolution above the BOM through Gradle's highest-wins rule.

Result: a wrapper compiled in a shared-library module against the BOM version, while the app
module compiles and runs a higher alpha pulled in by a colour/dynamic-theme library. The
library module never sees the newer API at all — so `ButtonGroup`, `FloatingToolbar`,
`LoadingIndicator` or `MaterialShapes` "do not exist" there, and a wrapper written against them
either fails to compile or crashes at runtime with `NoSuchMethodError`.

## Probe ladder

1. **Find the per-module platform.** Read the convention plugin:
   `configureCompose` / `configureAndroid` in `buildSrc/src/main/kotlin/<pkg>/buildlogic/ProjectExtensions.kt`.
   Look for `"implementation"(platform(compose.bom))` inside `commonExtension.dependencies {}`.
2. **List each module's declaration.** Grep all `*/build.gradle.kts` for the catalog alias
   (`compose.material3.core`) and for the suspected lifter (`materialKolor`, `coil`, any KMP
   wrapper). Whichever module declares the lifter is the only one that escapes the BOM.
3. **Get the exact lifted version from Gradle module metadata**, not the POM:
   `curl -fsSL https://repo1.maven.org/maven2/<group-path>/<artifact>/<version>/<artifact>-<version>.module`
   then read the `androidApiElements-published` / `androidRuntimeElements-published` variants:
   `jq -r '.variants[] | select(.name|test("androidApiElements")) | .dependencies[] | "\(.group):\(.module) -> \(.version.requires)"'`
   A JetBrains Compose Multiplatform artifact (`org.jetbrains.compose.*`) lists the real
   `androidx.compose.*` version it needs on its `-android` sibling.
4. **Enumerate what the module can actually call.** Class-name greps lie. Download the AAR and
   the **sources jar** for each candidate version and grep the Kotlin sources:
   `curl -fsSL -O <maven>/<artifact>/<version>/<artifact>-<version>-sources.jar && unzip -oq … -d src`
   then search `src/commonMain/androidx/.../*.kt` for `fun <Name>(`.
   Measured example: at `material3-android:1.4.0` the file list contains no `ButtonGroup.kt`,
   `FloatingToolbar.kt`, `LoadingIndicator.kt`, `MaterialShapes.kt`, `SplitButton.kt` or
   `WavyProgressIndicator.kt`, and `MaterialExpressiveTheme` is declared `internal` — uncallable.
   At `1.5.0-alpha14` all of them exist and `MaterialExpressiveTheme` is public behind
   `@ExperimentalMaterial3ExpressiveApi`.
5. **Check whether a stable line exists at all** before promising "use stable":
   `curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/maven-metadata.xml`
   A BOM bump is not an escape: several consecutive BOMs pinned material3 `1.4.0`.
6. **Compare opt-in wiring per module.** The expressive opt-in is a compiler argument, not an
   API: `"-opt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi"` in one module's
   `kotlin { compilerOptions { freeCompilerArgs } }` does nothing for another. Grep the sources
   for opt-in annotations too — a module-wide flag hides them, so `0` occurrences in source does
   not mean `0` opt-ins in the build.

## Fix

- Declare the version **once** in the version catalog and reference it from every module that
  compiles against the API. An explicit pin in one module does not bind the others.
- Make it authoritative, otherwise an automated dependency bump (Renovate/Dependabot updating the
  lifting library) re-splits the modules: add a `strictly`/`force` constraint in the convention
  plugin, or align all modules on the same explicit dependency.
- Prefer the version the app already resolves transitively over the newest published one, so the
  change is a declaration of the status quo rather than a behaviour change.
- Keep the opt-in at the wrapper package boundary: per-file `@OptIn` in the wrappers, so the
  experimental surface cannot leak into screens.

## Reporting

One row per module: module | catalog declaration | resolved version | opt-in present | API surface
available. State the resolving command for each row, and mark any API that exists but is `internal`
as "present, but uncallable".
