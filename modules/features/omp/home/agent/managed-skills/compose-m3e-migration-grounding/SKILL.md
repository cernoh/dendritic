---
name: compose-m3e-migration-grounding
description: "Ground a whole-app Material 3 Expressive migration in a Compose repo before planning: which expressive APIs exist at the pinned BOM, which module actually compiles against them, the per-module BOM platform trap and the materialkolor transitive escape, and how to pin the version once so modules cannot split. Use when asked to convert an Android app to M3E, when expressive components \"do not exist\" at the pinned BOM, or when one module cannot see an API another module uses."
---

# Grounding a whole-app M3E migration

Answer three questions with measurements before writing any plan: **does the API exist at the
pinned version**, **does the class get called** (internal vs public + opt-in marker), and **which
module actually compiles against it**. Artifact forensics (BOM POM, sources jar, javap, member
dumps) is covered by `skill://android-artifact-api-surface-forensics`; this skill covers the
migration-level consequences.

## 1. Resolve the version from the BOM, never from memory

```bash
curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom \
  | sed -n '/<artifactId>material3<\/artifactId>/,+1p'
curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/maven-metadata.xml \
  | sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' | tail -30
```

Measured 2026-09-20: compose-bom `2026.06.01`, `2026.08.00` and `2026.09.00` all pin
`androidx.compose.material3:material3 1.4.0`; the newest material3 published is `1.5.0-alpha28`;
**there is no `1.5.0` stable**. So "wait for stable" is not an option for a migration that needs
the expressive components.

## 2. Read the sources jar, never class names

Class-name greps lie: `MaterialExpressiveTheme` is a function in `MaterialTheme.kt`, not a class,
so a name scan reports it absent while it is present.

```bash
curl -fsSL -o s.jar ".../material3-android/<v>-sources.jar" && unzip -oq s.jar -d src-<v>
grep -rn '^fun ButtonGroup(\|^fun HorizontalFloatingToolbar(\|^internal fun MaterialExpressiveTheme(' src-<v>
```

Measured at 1.4.0 vs 1.5.0-alpha14:

| API | 1.4.0 (stable, BOM) | 1.5.0-alpha14 |
|---|---|---|
| `MaterialExpressiveTheme` | present but **`internal`** — uncallable | public, `@ExperimentalMaterial3ExpressiveApi` |
| `WideNavigationRail`, `ModalWideNavigationRail`, `ShortNavigationBar`, `AppBarRow`, `AppBarColumn`, `MotionScheme` | present | present |
| `ButtonGroup`, `Horizontal/VerticalFloatingToolbar`, `FlexibleBottomAppBar`, `LoadingIndicator`, `ContainedLoadingIndicator`, `Linear/CircularWavyProgressIndicator`, `FloatingActionButtonMenu`, `ToggleFloatingActionButton`, `SplitButtonLayout`, `MaterialShapes` | **absent** (tokens classes only) | present, `@ExperimentalMaterial3ExpressiveApi` |

App bar family at 1.5.0-alpha14: `TopAppBar`, `CenterAlignedTopAppBar`, `MediumTopAppBar`,
`LargeTopAppBar`, `MediumFlexibleTopAppBar`, `LargeFlexibleTopAppBar`, `TwoRowsTopAppBar`,
`BottomAppBar`, `FlexibleBottomAppBar`. `MaterialExpressiveTheme` defaults
`motionScheme = MotionScheme.expressive()`; `MotionScheme.standard()` exists to opt down.
`ButtonDefaults.shapes()` / `IconButtonDefaults.shapes()` / `toggleableShapes()` provide
press-time shape morphing.

## 3. Find which module compiles against which version — the trap

A Gradle BOM applied per module does **not** unify across modules, and a transitively pulled
higher version escapes it:

```bash
grep -rn 'platform(compose.bom)\|compose.material3\|materialKolor' --include=*.kts .
# then read the pulled artifact's Gradle module metadata (the POM is lossy for KMP)
curl -fsSL .../material-kolor-<v>.pom            # or .module
# org.jetbrains.compose.material3:material3:<JB ver> -> androidx.compose.material3:material3:<androidx ver>
```

Measured in Komikku: a `configureCompose` convention added
`implementation(platform(compose.bom))` to every Compose module, so each resolved `material3
1.4.0` on its own; only `:app` escaped, because `com.materialkolor:material-kolor:5.0.0-alpha07`
→ `org.jetbrains.compose.material3:material3:1.11.0-alpha03` → `androidx.compose.material3:material3:1.5.0-alpha14`,
and only `:app` carried `-opt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi`.
The other module could not even name the component it was supposed to wrap.

Symptoms to expect: `Unresolved reference: ButtonGroup` in one module while another compiles it;
a wrapper that compiles in library module A against the older version and crashes at runtime in
the app that runs the newer one (`NoSuchMethodError` / `NoClassDefFoundError`).

## 4. Pin once, and make it authoritative

- One version in the version catalog, referenced from **every** module that compiles expressive
  APIs (the wrapper module *and* the app). Do not hardcode the version string per module.
- An explicit dependency version beats a BOM's platform constraint (highest wins), but it does
  **not** stop a transitive bump: if an auto-updated dependency (`renovate.json`, a KMP library)
  raises the version later, the module without the explicit pin drifts and the split returns.
  Make the pinned version authoritative in the shared convention, e.g. a
  `constraints { implementation("androidx.compose.material3:material3") { version { strictly(v) } } }`
  or a `resolutionStrategy.force`, once drift is possible.
- Decide separately whether to move the BOM itself; moving it usually buys nothing when the
  newest BOM still pins the older stable line.

## 5. Verifying without a device

`./gradlew spotlessCheck assembleDebug` proves nothing visual. `javap` on the resolved artifact
confirms the opt-in marker a caller needs (`RuntimeInvisibleAnnotations`, BINARY retention); the
sources jar confirms `internal` vs public. If a compile-and-format bar is all that was agreed,
say plainly in the plan that no visual check exists before the APK reaches a device, and name who
will look.
