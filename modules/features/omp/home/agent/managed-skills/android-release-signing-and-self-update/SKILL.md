---
name: android-release-signing-and-self-update
description: "Sign a sideloaded Android app with a real release key and let it update itself from GitHub releases: the debug-keystore regeneration trap that makes your own releases mutually uninstallable, the mutable-PendingIntent crash on Android 14+, Shizuku's newProcess visibility across API versions, downloading a release asset from a public vs private repo, and verifying an in-app update by hashing the cached APK"
---

Ship a personal Android app that updates itself from its own GitHub releases. Proven on `cernoh/quotes` (AGP 9.2.1, Gradle 9.7.1, minSdk 26, targetSdk 36, NixOS host, Pixel 9 on Android 17), 2026-09-19.

## The trap that breaks the user's install: two debug keys

A debug APK can never update another debug APK. AGP resolves the debug keystore through the Android "user home", and if you ever delete that directory the keystore is **regenerated**, so the next release is signed by a different key. Symptom on the device:

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package com.example.app signatures do not match newer version; ignoring!
```

This cost a real user their install after two releases. Diagnose by comparing certificates, never by guessing:

```sh
apksigner verify --print-certs a.apk | sed -n '/certificate DN/p;/SHA-256 digest/p'
```

Two releases showed different digests (`355b44a7…` vs `c12e7abe…`) with the same `CN=Android Debug`. If you caused it, say so plainly and fix the cause: a release keystore. Note that a signing change makes every existing install uninstallable-over — the user must uninstall once, and that is unavoidable.

Also note: if you point `ANDROID_USER_HOME` into the project (a common trick to keep AVD state in the checkout) and then `rm -rf .android`, you regenerate the debug key. Either never delete it, or do not rely on the debug key for releases.

## Release signing that keeps the secrets out

```sh
mkdir -p ~/.android-keys
keytool -genkeypair -v -keystore ~/.android-keys/app-release.jks \
  -alias app -keyalg RSA -keysize 4096 -validity 10000 \
  -storepass "$PW" -keypass "$PW" -dname 'CN=name, OU=app, O=name, C=GB'
```

Wire it from a gitignored properties file so `assembleRelease` still works for anyone else (and for F-Droid, which builds from source and signs with its own key):

```kotlin
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}
// in buildTypes.release:
if (keystoreProperties.isNotEmpty()) {
    signingConfig = signingConfigs.create("release") {
        storeFile = file(keystoreProperties.getProperty("storeFile"))
        storePassword = keystoreProperties.getProperty("storePassword")
        keyAlias = keystoreProperties.getProperty("keyAlias")
        keyPassword = keystoreProperties.getProperty("keyPassword")
    }
}
```

Commit `keystore.properties.example`, gitignore `keystore.properties`, `*.jks`, `*.keystore`. Verify the result: `apksigner verify --print-certs` must name your DN, not `CN=Android Debug`, and report v2 and v3. With minSdk 26, scheme v1 stays off — AGP disables it and an explicit `enableV1Signing = true` does not override that; do not make v1 an acceptance criterion.

Prove the whole point of the exercise before releasing: build 0.N, install it, build 0.N+1 with the same key, `adb install -r` it, and confirm the version changed. `setContentView`-level behaviour is irrelevant here; the signature is the contract.

The keystore MUST NOT enter the repository, and losing it means the app can never be updated again. Say that in the README.

## The mute that kills every install: commit() needs a mutable PendingIntent

On Android 14+ the system writes the install result into the PendingIntent you hand `PackageInstaller.Session.commit`, so an immutable one throws and kills the app:

```
java.lang.IllegalArgumentException: The commit() status receiver should come from a mutable PendingIntent
  at dev.example.Updates.install(Updates.kt:182)
```

```kotlin
val flags = PendingIntent.FLAG_UPDATE_CURRENT or
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
session.commit(PendingIntent.getBroadcast(context, 51, resultIntent, flags).intentSender)
```

Nothing in `assembleDebug` or lint catches this. It only appears when an update is actually installed, so an untested install path hides it indefinitely.

## Downloading the release asset

A **private** repository needs the API asset endpoint with the token; `browser_download_url` is a github.com address that wants a signed-in web session and 404s:

```
https://api.github.com/repos/<owner>/<repo>/releases/assets/<asset id>
Accept: application/octet-stream
Authorization: Bearer <token>
```

So parse `assets[].id`, not the browser URL, and skip an asset without an id. For a **public** repository the same endpoint works anonymously, and `releases/latest` answers 200 — which is what makes a token-free in-app updater possible. Turning the repository public is the single cheapest way to make a personal app's self-update work; note the token-free path only disappears if it goes private again.

## Optional silent install through Shizuku

Shizuku runs a command as the shell user, so `pm install` needs no system prompt. `Shizuku.newProcess` is **public in api 12.2.0 and private from 13.0** — verify with `javap` on the AAR's `classes.jar`, not on a jar URL (the `api` artifact is an `.aar`; `api-13.1.5.jar` 404s and leaves you a 554-byte HTML file that silently answers nothing). Pin 12.2.0, or rewrite as a `bindUserService` service for 13.x.

The install streams the APK on stdin so an app-private cache file never has to be readable by the shell user:

```kotlin
val process = Shizuku.newProcess(
    arrayOf("pm", "install", "-r", "-S", apk.length().toString()), null, null)
apk.inputStream().use { input -> process.outputStream.use { input.copyTo(it) } }
val out = process.inputStream.bufferedReader().readText() + process.errorStream.bufferedReader().readText()
val code = process.waitFor()
check(code == 0 && out.contains("Success")) { out.trim() }
```

Declare `rikka.shizuku.ShizukuProvider` in the manifest with `android:permission="android.permission.INTERACT_ACROSS_USERS_FULL"` and authority `${applicationId}.shizuku`. Keep the feature opt-in: a switch that refuses to turn on unless the state is READY, and a fallback to the system installer on every path.

`Shizuku.pingBinder()` answers `false` rather than throwing when nothing runs, so it cannot distinguish absent from not-running. Check the installed package (`moe.shizuku.privileged.api`) first, or the user reads "installed, but not running" for an app they never installed.

Starting Shizuku on an emulator: `adb root` (AOSP userdebug images allow it) then run the app's own starter, which Shizuku prints under "View command" — in 13.x it is a native library, not `app_process`:

```sh
adb shell 'SO=$(ls -d /data/app/*/moe.shizuku.privileged.api-*/lib/x86_64/libshizuku.so | head -1);
  setsid nohup $SO > /data/local/tmp/sz.log 2>&1 < /dev/null &'
adb shell ps -A | grep shizuku_server      # expect: root  <pid>  shizuku_server
```

The "Start (for rooted devices)" button needs a real `su` (Magisk), which an emulator lacks.

## Verify the update by hashing what the app fetched

Screenshots of the version string are weak. Pull the cache file and compare digests:

```sh
adb shell sha256sum /data/data/<pkg>/cache/update.apk
gh release download v0.N --dir /tmp/x --clobber && sha256sum /tmp/x/*.apk
```

Equal digests prove the updater fetched the published artifact, not something else. On a fresh install with no cache, the same app path can be exercised by pushing a build into the cache with root adb, which is also how to test the install half without publishing a throwaway release.

## Emulator notes

- AOSP `default` images could not complete a `PackageInstaller` session: `markAsSealed` logged `ServiceNotFoundException: No service published for: persistent_data_block`, no installer screen appeared, and the version did not change. Record that as "unconfirmed", not as "the image cannot do it" — one log line is not proof of the cause.
- A second emulator cannot take port 5554 if one is already running; the pre-existing one answers your `adb -s` calls and you will test the wrong device. Ask the live device for its identity: `adb -s <serial> emu avd name`.
- Do not hardcode a nix store path for the SDK. It moves when the shell is rebuilt, and a stale hash yields `error: command not found: /nix/store/<old>-androidsdk/libexec/...`. Run tools through the shell instead: `nix-shell shell.nix --run '$ANDROID_HOME/platform-tools/adb …'`.
