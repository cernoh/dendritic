---
name: android-app-widget-remoteviews
description: "Build an Android home screen app widget (Kotlin RemoteViews, AGP 9) plus a self-updating APK, and verify both on a headless emulator: size-option traps, Shizuku silent install pinned to api 12.2.0, the mutable-PendingIntent crash on Android 14+, and the verification traps that make a check silently pass"
---

Kotlin `RemoteViews` app widget, settings screen, and a self-updating APK, verified on a headless emulator. Proven on `cernoh/quotes` (AGP 9.2.1, Gradle 9.7.1, JDK 21, Android 16 / API 36 x86_64) on NixOS, 2026-09-19. Companion to `nixos-agp-emulator-screenshot-loop` (SDK shell, aapt2 trap) — this covers the app itself.

## AGP 9 carries Kotlin

```
Failed to apply plugin 'org.jetbrains.kotlin.android'.
The 'org.jetbrains.kotlin.android' plugin is no longer required for Kotlin support since AGP 9.0.
```

Drop the Kotlin plugin from both `build.gradle.kts` files; there is no `kotlin { }` extension after that. A framework-only app needs no dependency at all.

## RemoteViews constraints

- **`View` is not supported.** A divider must be a `TextView` with a background colour and a 1dp height.
- **Give the quote `android:maxLines` and `ellipsize="end"`**, or a long quote eats the card and the attribution is never drawn.
- Inflate the same card layout in the activity, so the preview *is* the widget.
- `updatePeriodMillis` floors at 30 minutes. Use `0` and drive rotation from `AlarmManager.setInexactRepeating`; Android will not repeat faster than 15 minutes. `onUpdate` MUST NOT advance the quote (the launcher redraws whenever), advance only in `onReceive`.
- Keep the shuffle seed, not the shuffled list, so a redraw after a reboot keeps the order.
- Font: `res/font/<family>.xml` with `fontStyle` entries so `textStyle="italic"` picks the real italic; `androidResources { noCompress += listOf("otf", "ttf") }`.

## Widget sizing: read the right option pair

The placed size comes from `AppWidgetManager.getAppWidgetOptions(id)`, and the four numbers are orientation-dependent:

```kotlin
fun currentSize(portrait: Boolean, minWidth: Int, minHeight: Int, maxWidth: Int, maxHeight: Int) =
    if (portrait) minWidth to maxHeight else maxWidth to minHeight
```

Measured on an emulator for a 3x2 placement: `min 224x136`, `max 434x284`, and the widget draws 224 wide by 284 high. Reading `minHeight` (136) instead of `maxHeight` (284) sized the card for half its real height and left the lower half empty. This cost a build and a logcat round; log all four values first (`adb logcat -s <tag>:I`).

A launcher that has not filled the options answers `0`, and `0` selects the smallest card. Fall back per number to the declared size:

```kotlin
val declared = manager.getAppWidgetInfo(id)   // AppWidgetProviderInfo? , dp
val width = if (reportedW > 0) reportedW else declared?.minWidth ?: 0
```

Derive the line limit from the height, not from a fixed class: compute `(height - chrome) / lineHeight`, and drop to a smaller class when the result is below your floor. Decide the work-title visibility in **one** function — a renderer that hides it in the tier step and shows it again in the content step draws a line the height never budgeted for.

`onAppWidgetOptionsChanged` MUST redraw, or a resize keeps the old measurements.

## Self-update from GitHub releases

- **Private repository:** `assets[].browser_download_url` needs a signed-in web session and 404s. Use the API asset endpoint with the asset id and the token:
  `https://api.github.com/repos/<owner>/<repo>/releases/assets/<id>`, `Accept: application/octet-stream`, `Authorization: Bearer <token>`. Anonymous access to a private repository answers `404`, so report a missing token rather than a network fault.
- **`PackageInstaller.Session.commit` needs a MUTABLE PendingIntent** on Android 14+:
  `java.lang.IllegalArgumentException: The commit() status receiver should come from a mutable PendingIntent`, thrown on the caller's thread — the app dies. Use `FLAG_UPDATE_CURRENT or (FLAG_MUTABLE if SDK_INT >= 31 else 0)`. Neither `assembleDebug` nor lint catches it.
- Keep the downloaded APK in the cache and offer to install it later, so an interrupted update is not re-downloaded.
- Version comparison: strip a leading `v`, split on `.`/`-`/`+`, compare numerically (`0.1.10` > `0.1.9`; a text compare gets that wrong).
- A release build needs numbers from the command line: `versionCode = (findProperty("versionCode") as String?)?.toInt() ?: 1`.

## Shizuku: install with no prompt

Shizuku runs a command as the shell user. **Pin `dev.rikka.shizuku:api` and `:provider` to 12.2.0**: `Shizuku.newProcess(String[], String[], String)` is *public* there and **private from 13.0**, where the only route is `bindUserService` with a UserService. The artifacts are `.aar`, not `.jar` (`api-12.2.0.aar`), and they drag `androidx.annotation` in — the one androidx entry to justify.

```kotlin
val process = Shizuku.newProcess(arrayOf("pm", "install", "-r", "-S", apk.length().toString()), null, null)
apk.inputStream().use { input -> process.outputStream.use { out -> input.copyTo(out) } }
```

Streaming on standard input means the app-private cache file never has to be readable by the shell user. Manifest needs the provider:

```xml
<provider android:name="rikka.shizuku.ShizukuProvider"
    android:authorities="${applicationId}.shizuku" android:enabled="true"
    android:exported="true" android:multiprocess="false"
    android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
```

`Shizuku.pingBinder()` is `binder != null && binder.pingBinder()` and does **not** throw, so a `catch`-based "not installed" state is unreachable — a user without Shizuku reads "installed but not running". Check `PackageManager` for `moe.shizuku.privileged.api` instead.

Keep the feature opt-in: a switch that refuses to turn on unless the state is READY, and a fallback to the system installer on every other path.

### Starting the Shizuku server on an emulator

- `adb root` makes **adbd** root, not the Shizuku app. "Start (for rooted devices)" needs a real `su` (Magisk), which an AOSP userdebug image does not have.
- Shizuku 13.x starts its server from a native library, `lib/x86_64/libshizuku.so`, not from `app_process`. Do not hand-roll the server class.
- The supported route: launch the Shizuku app, open *Start by connecting to a computer*, tap *View command*, and run the exact path it prints. That also writes `start.sh` next to it. Run it and confirm `ps -A | grep shizuku_server` shows a root process.
- The ADB path is documented for Android 10 and below; on newer releases wireless debugging pairing is the supported route.

## Verification traps that make a check silently pass

- **`uiautomator dump` flakes on some AVDs**, returning one node. When it does, do not fall back to reading coordinates off a screenshot: verify the *focused* activity instead
  (`dumpsys activity activities | sed -n 's/.*topResumedActivity=ActivityRecord{[^ ]* [^ ]* \([^ ]*\).*/\1/p'`).
- **A capture that is byte-for-byte the previous screen means the second activity never opened** (`am start -n <pkg>/.SettingsActivity` fails with a security exception for a non-exported activity; you then photograph the previous screen and believe you verified the new one).
- **`javap` on the wrong classpath prints "Error: class not found" and a banner.** Check the file's content before trusting `grep` on it. Kotlin classes land in
  `app/build/intermediates/built_in_kotlinc/debug/compileDebugKotlin/classes`, not `app/build/tmp/kotlin-classes`.
- **Prove an API-level crash fix by the absence of the specific call**, not by grepping a class name: `javap -c` on the class and look for `android/graphics/Insets.of` (API 29) in a branch that also runs on API 26–28. `WindowInsets`, `getInsets`, and `Insets` fields all match a loose grep and legitimately appear in the API 30+ branch.
- **Prove a bundled font is really used:** build a control variant with `android:fontFamily="serif"`, capture both (`adb exec-out screencap > f.raw`, 12-byte header then RGBA8888), and diff a region. Measured: 17.9% of card pixels changed, max channel delta 217, against 0.35% in a status-bar control strip.
- **Prove a tap by text, not only pixels:** `uiautomator dump` exposes the widget's `TextView` values, so the before and after dumps name the two quotes.
- Read tap coordinates from `uiautomator dump` `bounds`, never from a scaled screenshot: `input tap` uses real pixels while a vision read reports the displayed size.
- AOSP `default` images log `No service published for: persistent_data_block` during `markAsSealed`. `session.commit()` still returned in a test, so do not record it as "the image cannot install": check `dumpsys package installer` and whether your status receiver fired before claiming anything about the session's fate.
