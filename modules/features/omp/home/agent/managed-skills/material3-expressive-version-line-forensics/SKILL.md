---
name: material3-expressive-version-line-forensics
description: "Settle which androidx material3 version a Compose app truly compiles against (BOM pin vs. via transitive KMP alpha), which expressive APIs are callable there, and which module an experimental wrapper may safely live in — from published artifacts, no Gradle run. Use before planning an M3 Expressive migration, when the BOM version and the API you need disagree, or when a wrapper module lacks the app's opt-in flag."
---

# Which material3 line does this app really compile against?

Companion to `android-artifact-api-surface-forensics` (API existence and opt-in markers).
This skill answers the *version* question first, because it changes the answer.

## The two questions that decide an M3 Expressive migration

1. **Which `androidx.compose.material3:material3` version wins resolution?** The BOM pins a
   version; a transitive KMP library can outbid it.
2. **Which module can hold the wrapper?** A module without the alpha pin and without the
   `-opt-in=...ExperimentalMaterial3ExpressiveApi` compiler arg cannot see expressive APIs at all.

## Ladder

1. **BOM pin, from the BOM POM** (not memory):
   ```bash
   curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom \
     | sed -n '/<artifactId>material3<\/artifactId>/,+1p'
   ```
   Check the newest BOM too (`.../compose-bom/maven-metadata.xml`): if the newest stable BOM still
   pins the same version, there is no stable escape hatch for the API you need.
2. **Is there a stable release at all?**
   ```bash
   curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/maven-metadata.xml \
     | sed -n 's/.*<version>\(.*\)<\/version>.*/\1/p' | tail -30
   ```
   A line of only `-alphaNN` releases means any expressive-component work rides an alpha.
3. **Gradle module metadata is the authority on the real dependency graph** (POMs are lossy for KMP):
   ```bash
   curl -fsSL https://repo1.maven.org/maven2/com/materialkolor/material-kolor/<v>/material-kolor-<v>.pom
   curl -fsSL https://repo1.maven.org/maven2/org/jetbrains/compose/material3/material3/<v>/material3-<v>.module \
     | jq -r '.variants[] | select(.name=="androidApiElements-published") | .dependencies[] | "\(.group):\(.module) -> \(.version.requires)"'
   ```
   A `org.jetbrains.compose.*` artifact's `androidApiElements-published` variant names the
   `androidx.*` coordinates it maps to. Highest version wins over the BOM's dependency
   constraint, so the app may be compiling an alpha nobody declared.
4. **Sources jar, not class names, for what is callable.** Class-name greps lie twice: a composable
   usually has no class of its own, and a function that exists can still be `internal`.
   ```bash
   curl -fsSL -o s.jar <artifact>-<v>-sources.jar && mkdir -p src && unzip -oq s.jar -d src
   grep -n "^\(\|internal \|public \)fun <ApiName>" src/commonMain/androidx/compose/material3/*.kt
   ```
   Evidence from the 2026-09 round: at material3 **1.4.0** (stable) `MaterialExpressiveTheme` is
   `internal fun` in `MaterialTheme.kt` — uncallable from app code — and `ButtonGroup.kt`,
   `FloatingToolbar.kt`, `LoadingIndicator.kt`, `MaterialShapes.kt`, `SplitButton.kt`,
   `WavyProgressIndicator.kt` do not exist; at **1.5.0-alpha14** all of them exist, with
   `@ExperimentalMaterial3ExpressiveApi` on `MaterialExpressiveTheme`, `ButtonGroup`,
   `FloatingToolbar`, `LoadingIndicator`, `WavyProgressIndicator`, `FloatingActionButtonMenu`,
   `SplitButtonLayout`. `WideNavigationRail`, `ModalWideNavigationRail`, `ShortNavigationBar`,
   `AppBarRow`, `MotionScheme` exist in both.
5. **Check opt-in per module, not just in `:app`.** A `-opt-in=androidx.compose.material3.ExperimentalMaterial3ExpressiveApi`
   flag in one module's `kotlin { compilerOptions { freeCompilerArgs.addAll(...) } }` does nothing
   for a sibling module. The wrapper belongs where both the alpha pin and the flag are present,
   or that module must gain both.

## Traps

- **Stable-line "expressive theme" can be internal.** An app that compiles `MaterialExpressiveTheme`
  is *not* on the stable line, whatever the BOM says — resolution was outbid.
- **One alpha dependency moves the entire Compose stack.** `org.jetbrains.compose.foundation`/`ui`
  android variants map to `androidx.compose.foundation:foundation` / `ui` at their own alpha
  versions, so `foundation`, `ui`, and `runtime` also rise above the BOM.
- **Bumping the BOM is not the fix** when the newest stable BOM still pins the stable material3;
  only an explicit alpha pin (or waiting for the stable release) reaches the components.
- **Per-module dependency declarations decide what compiles**, not what the app module resolved.
- Absence claims need the command that showed them: report "absent at version V, sources-jar
  listing of `*Kt.kt` files" rather than a blank.
