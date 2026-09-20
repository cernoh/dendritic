---
name: android-inapp-update-shizuku
description: "Ship an in-app updater for a sideloaded Android app (GitHub releases, API asset download, PackageInstaller mutable PendingIntent) plus an optional Shizuku silent-install path: api 12.2.0 pin, libshizuku.so server start, streaming pm install, state from PackageManager, and the verification recipes"
---

Ship an in-app updater for a sideloaded Android app (GitHub releases), plus an optional Shizuku route that installs without a prompt. Proven on `cernoh/quotes` (AGP 9.2.1, Gradle 9.7.1, API 36 x86_64 emulator), 2026-09-19. Build/verify basics live in `android-app-widget-remoteviews`.

## Version numbers come from the build

```kotlin
versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: 2
versionName = (project.findProperty("versionName") as String?) ?: "0.2.0"
```

Raise the committed defaults in the release PR, then tag. A tag whose source still builds the old number is a lie. For the test build that must look *older*, pass `-PversionCode=1 -PversionName=0.1.0`.

## Release notes and assets

- `gh release upload file#name` does NOT rename: the asset keeps the file's basename. Delete the asset and upload a copy with the wanted name.
- `gh release download` needs a repository context: pass `--repo owner/name` or run inside the checkout.
- Verify the published bytes: download the asset and compare `sha256sum` with the local build.

## The update check

- Public repository: `GET https://api.github.com/repos/OWNER/REPO/releases/latest` answers `200` anonymously — no token, no header beyond `Accept: application/vnd.github+json`.
- Private repository: the same call answers **`404`**, not `401`. Report that as a missing token, never as a network fault.
- Version compare: strip a leading `v`, split on `.`/`-`/`+`, compare numerically. A text compare gets `0.1.10` vs `0.1.9` wrong.
- **Download through the API asset endpoint, not `browser_download_url`.** The browser URL of a private repository needs a signed-in web session and 404s. Use `https://api.github.com/repos/OWNER/REPO/releases/assets/<assets[].id>` with `Accept: application/octet-stream` and the token; GitHub redirects to a signed S3 address. Keep the asset `id`, not the URL, in the parsed release model.

## `PackageInstaller` needs a MUTABLE PendingIntent

On Android 14+ `session.commit()` rejects an immutable one:

```
java.lang.IllegalArgumentException: The commit() status receiver should come from a mutable PendingIntent
```

Use `FLAG_UPDATE_CURRENT or FLAG_MUTABLE` (guarded by `SDK_INT >= S`), keep the receiver `exported="false"`. Neither `assembleDebug` nor lint catches this, and the failure kills the whole app.

Measured limitation: on the AOSP `default` x86_64 emulator images the system installer path produced no installer screen and no version change, with logcat showing `markAsSealed` → `ServiceNotFoundException: No service published for: persistent_data_block`. One log line is not a diagnosis: check `dumpsys package installer` and the commit receiver before concluding anything.

## Shizuku, when the user opts in

- **Pin the API to 12.2.0.** `Shizuku.newProcess` is `public static` there and private from 13.0 (verify with `javap` on the AAR's `classes.jar`; the `api` artifact is an `.aar`, so a `.jar` download is a 404 you will misread as "no classes"). Moving to 13.x means rewriting the install as a `bindUserService` service.
- The API drags `androidx.annotation`, the one androidx artifact — record that in the project's dependency contract instead of leaving a "no androidx" rule contradicting the build.
- Manifest provider is required:
  ```xml
  <provider android:name="rikka.shizuku.ShizukuProvider"
      android:authorities="${applicationId}.shizuku"
      android:enabled="true" android:exported="true" android:multiprocess="false"
      android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
  ```
- **States must come from the package, not an exception.** `Shizuku.pingBinder()` returns `false` rather than throwing when nothing runs, so a catch-based `NOT_INSTALLED` is unreachable and a user without Shizuku reads "installed, but not running". Check `PackageManager.getPackageInfo("moe.shizuku.privileged.api", 0)` first.
- **Silent install** streams the APK, so an app-private cache file works without world-readable storage:
  ```kotlin
  val p = Shizuku.newProcess(arrayOf("pm", "install", "-r", "-S", apk.length().toString()), null, null)
  apk.inputStream().use { input -> p.outputStream.use { input.copyTo(it) } }
  // read stdout+stderr, waitFor(); success when the output contains "Success"
  ```
- **Starting the Shizuku server headlessly** (API 36 AOSP image, no wireless-debugging pairing): `adb root` (userdebug images allow it), then run the library the app itself prints under "View command":
  ```sh
  adb shell 'SO=$(ls -d /data/app/*/moe.shizuku.privileged.api-*/lib/x86_64/libshizuku.so | head -1); setsid nohup $SO > /data/local/tmp/shizuku.log 2>&1 < /dev/null &'
  ps -A | grep shizuku_server    # expect a root process
  ```
  Do not hand-roll `app_process ... rikka.shizuku.server.ShizukuService`: the 13.x entry point is the native library. The app's "Start (for rooted devices)" needs a real `su`, which `adb root` does not provide.
- Grant the permission through Shizuku's own dialog (tap *Allow all the time*), then the app's state line goes READY.

## Verifying an install without a store

- Prove the update is real: build a higher `versionCode`, put it in the app cache (`adb root` then `cp` the APK to `/data/data/<pkg>/cache/update.apk` and `chown` it to the app's uid), and drive the app's own button.
- Prove the outcome by the installed version, not the absence of a dialog: `adb shell dumpsys package <pkg> | sed -n 's/.*versionName=//p'`.
- Prove the *download* independently by hashing the cached file against the release asset.
- Setting a switch the UI binds is a fast way to reach a guarded code path: write the SharedPreferences XML as root, `force-stop`, relaunch, and check the control renders in the changed state. Say that you did that rather than implying a tap.
- Tap discipline: pull `uiautomator dump` bounds **immediately before** the tap, in the same command, and tap the centre of the returned `bounds`. Coordinates measured from an earlier screenshot miss, because a `ScrollView` sits at a different offset by tap time. Four consecutive misses in one session came from reusing coordinates across commands.
