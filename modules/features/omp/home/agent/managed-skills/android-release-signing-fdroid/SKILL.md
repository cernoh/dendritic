---
name: android-release-signing-fdroid
description: "Sign an Android app for release with a stable key (not debug), keep the keystore outside the repo, verify with apksigner, prove update-over on an emulator, and prepare F-Droid packaging including the licence and bundled-content audit"
---

# Android release signing for a sideloaded app (plus F-Droid readiness)

Proven on the `cernoh/quotes` Android app (AGP 9.2.1, Gradle 9.7.1, NixOS host), 2026-09-19.

## Why debug signing cannot ship

- Android only accepts an update signed by the same key as the installed copy.
- Every machine generates its own debug keystore, so two debug-signed builds
  from different environments, or from the same environment before and after a
  keystore regeneration, NEVER match. Symptom on device:
  `INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package <pkg> signatures do not
  match newer version`.
- A user hit this with two builds that were minutes apart, because the build
  environment's keystore home was regenerated between them.

## The trap that regenerates a debug keystore

If the build environment points `ANDROID_USER_HOME`/`ANDROID_AVD_HOME` into the
project (a common NixOS pattern for read-only stores), then `rm -rf .android`
for tidiness deletes the debug keystore too, and the next build signs with a NEW
key. Never delete that directory without confirming where the keystore lives
(`keytool -list` on the produced APK, or `apksigner verify --print-certs`).

## Set up a stable release key

```sh
keytool -genkeypair -v -keystore ~/.android-keys/<app>-release.jks \
  -alias <app> -keyalg RSA -keysize 4096 -validity 10000
```

Store it outside the repository. Wire it through a gitignored properties file
with a committed template, so no secret reaches git:

```kotlin
import java.util.Properties
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (keystoreProperties.isNotEmpty()) {
                signingConfig = signingConfigs.create("release") {
                    storeFile = file(keystoreProperties.getProperty("storeFile"))
                    storePassword = keystoreProperties.getProperty("storePassword")
                    keyAlias = keystoreProperties.getProperty("keyAlias")
                    keyPassword = keystoreProperties.getProperty("keyPassword")
                    enableV2Signing = true
                    enableV3Signing = true
                }
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

- In a `.gradle.kts` script, import `java.util.Properties`; fully qualified
  `java.util.Properties` in an expression fails to resolve.
- Losing the keystore means the app can never be updated again. Say so in the
  README and tell the user to back it up.

## Verify

```sh
$ANDROID_HOME/build-tools/<ver>/apksigner verify --print-certs --verbose app-release.apk
```

- The certificate DN must NOT be `CN=Android Debug`.
- Schemes v2 and v3 verified is sufficient at minSdk >= 24; scheme v1 is not
  needed there even if the signing config asks for it (AGP may override it).
- Update test: install release A, build release B with the same key, install B
  over A, and check both report their correct versions. Building A and B back to
  back can leave only the last one in `outputs/apk/release/`, so save each APK
  before building the next.
- A minified (R8) release must be run-tested, not just built: keep every
  manifest-referenced component with `-keep` rules, then launch each activity and
  read `dumpsys activity activities` for the focused one. Note that `adb shell
  am start` cannot open an activity with `exported="false"` (SecurityException);
  navigate through the UI instead, tapping bounds taken from a `uiautomator
  dump` made immediately before the tap, in the same shell invocation.

## The F-Droid route

F-Droid builds from source and signs with its own key, so:

- The build MUST tolerate a missing keystore properties file and produce an
  unsigned APK. Verify by moving the properties file away and building.
- The repository needs an explicit FOSS licence file; F-Droid metadata names it.
- Metadata lives in the fdroiddata repo as `metadata/<pkg>.yml` (Categories,
  License, Repo, RepoType, Builds with commit/subdir/gradle, AutoUpdateMode,
  UpdateCheckMode). Keep an in-repo copy for the merge request.
- An F-Droid build and a sideloaded build can never replace each other: the
  signatures differ. Pick one route per device.
- Audit bundled content licences before submitting. Quotes from long-dead
  authors are public domain, but their MODERN ENGLISH TRANSLATIONS often are
  not; a corpus gathered from Wikiquote can carry them. F-Droid reviewers look
  at bundled content, and a distributed APK is a different exposure than a
  personal widget. Decide before submitting: public-domain translations only, or
  an anti-feature note.

## Shizuku notes (if the app self-updates)

- Pin the Shizuku API deliberately. `Shizuku.newProcess` is public in 12.2.0 and
  private from 13.0 (checked with `javap` on the AAR's `classes.jar`; a `.jar`
  URL on Maven for Shizuku 404s, the artifact is an `.aar`).
- State detection: decide presence from the installed package
  (`getPackageInfo("moe.shizuku.privileged.api")`), because
  `Shizuku.pingBinder()` answers `false` instead of throwing when nothing runs.
- Silent install: run `pm install -r -S <size>` as the shell user and stream the
  APK on standard input, so an app-private cache file needs no permission bits.
- The app's manifest must declare the Shizuku provider with
  `INTERACT_ACROSS_USERS_FULL` so the server hands its binder over.
- `PackageInstaller.Session.commit` needs a MUTABLE `PendingIntent` on Android
  14 and later; an immutable one kills the app with
  `IllegalArgumentException: The commit() status receiver should come from a
  mutable PendingIntent`. Neither `assembleDebug` nor lint catches it.
