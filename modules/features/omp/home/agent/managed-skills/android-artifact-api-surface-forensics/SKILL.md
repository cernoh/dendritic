---
name: android-artifact-api-surface-forensics
description: "Settle which AndroidX/Compose APIs exist, are callable, and need opt-in at a pinned BOM version, from published artifacts only (no JDK, no Gradle build): BOM resolution, sources jar for Kotlin visibility, javap for opt-in markers, member dumps instead of class-name greps."
---

# Android artifact API-surface forensics

Use when a question is "does API X exist at the version this project pins, is it callable, and
does a caller need an opt-in marker?" and no build is possible. Answer it from the published
artifacts on Google Maven. No JDK, no Android SDK, and no Gradle resolution are required; a
JDK is useful but optional.

Verified on 2026-09-18 against `androidx.compose.material3:material3-android:1.4.0` (Compose BOM
2026.05.01), where the same method produced a headline that contradicted widely published
knowledge of that release.

## Ladder

1. **Resolve the version, from the BOM POM, not from memory.**
   `curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom`
   The POM lists every managed coordinate with its version; `material3` is in it, and the
   `-android` artifact is what actually ships the code.
2. **Check whether a coordinate exists at all** with the group index, which lists every artifact
   name and version under a group:
   `curl -fsSL https://dl.google.com/dl/android/maven2/androidx/compose/material3/group-index.xml`
   This is how you prove that no "expressive" artifact exists rather than guessing.
3. **Read the AAR's Gradle module metadata for the true dependency list** (the POM is lossy for
   Kotlin multiplatform artifacts):
   `.../material3-android/1.4.0/material3-android-1.4.0.module`
   Absence of a coordinate here is the answer to "is X transitive?".
4. **Get the sources jar — it is the authority on Kotlin visibility and opt-in.**
   `curl -fsSL -O .../material3-android-1.4.0-sources.jar && unzip -o -q ...-sources.jar -d src`
   Then grep `src/commonMain/androidx/.../*.kt` for the declaration. Kotlin sources carry
   `internal` and `@ExperimentalFooApi` verbatim, and the file list settles absence of a whole
   component (`ButtonGroup.kt`, `MaterialShapes.kt`) without a class-file detour.
5. **Use bytecode only to confirm what the sources cannot show**: the annotation a *caller* must
   opt into lands in `RuntimeInvisibleAnnotations` (Kotlin opt-in markers have BINARY retention).
   `unzip -o -q material3-android-1.4.0.aar classes.jar -d m3 && javap -v -p -cp m3/androidx/...`
   Java is absent on NixOS hosts here; get one with
   `nix shell nixpkgs#jdk21 --command javap -v -p -cp <dir> <fqcn>` (about 8 s when cached).
6. **Enumerate members across the whole artifact when a component seems absent.** Dump every
   public class and search the member lines:
   `unzip -l classes.jar | awk '/\.class$/ && !/\$/' | ... | xargs javap -p -cp <dir> > all_members.txt`
7. **A cheap containment check** for "does anything in this jar reference marker M" is a byte
   scan over the extracted classes. A marker referenced only by its own class file is a marker no
   API requires. Pair it with a positive control on an earlier version that does reference it.

## Traps that cost real time

- **Class-name greps lie.** A composable or object symbol usually has no class of its own:
  `FlexibleBottomAppBar` is a method in `AppBarKt`, so `grep FlexibleBottomAppBar` over class
  names returns 0 while the API exists. Never report absence from class names alone; dump
  members (step 6) or the sources jar (step 4).
- **`javap` cannot see Kotlin visibility.** A Kotlin `internal` declaration is a public JVM
  symbol. Worse, name mangling does not discriminate: `MaterialTheme` has unmangled
  `getMotionScheme(...)` (internal in source) beside mangled `getLocalMotionScheme$material3()`
  (also internal), and `ShapeDefaults` has unmangled `getExtraLarge()` (public) beside mangled
  `getExtraExtraLarge$material3()` (internal). So neither the mangled nor the unmangled form
  proves anything; the `*$<module>` suffix only proves internal when present. Read the sources jar.
- **An `internal` opt-in marker is unenforceable.** If the marker class itself is
  `internal annotation class`, no external caller can name it, and a scan showing it applied to
  nothing means the surface it guarded is gone, not that the surface is stable.
- **Removal is announced in release notes, and the notes are searchable.** Grep the
  first-party page (`https://developer.android.com/jetpack/androidx/releases/<library>`) for the
  symbol or the marker; a sentence like "All public APIs tagged with X have been removed, please
  switch to <version>" reframes the whole answer and points at the line that still has them.
- **Artifacts are version-scoped**: check `alpha`/`beta` artifacts of the same line to see when a
  symbol disappeared, and to use as a positive control for marker scans.
- **Platform floors come from three places**: the AAR manifest (`minSdkVersion`),
  `META-INF/com/android/build/gradle/aar-metadata.properties` (`minCompileSdk`,
  `minAndroidGradlePluginVersion`), and `androidx.annotation.RequiresApi` /
  `RequiresExtension` in `RuntimeInvisibleAnnotations`.
- **A KMP root jar can be a metadata-only stub** (`commonMain/*.knm`, no classes); the real
  classes are in the `-android` sibling artifact. An empty AAR does not mean an empty API.

## Reporting

One table row per asked-about API: API | owning artifact and version | present or absent |
opt-in marker or `stable` | min API | the re-runnable command that settled it. State absences
with the command that showed them, never as a blank. Mark internal-only rows as
"present, but internal — uncallable" so a reader cannot mistake them for usable.
