---
name: android-emulator-screenshot-state-seeding
description: "Seed app state on a headless Android emulator so UI screenshots are possible (bypass the first-run wizard, drive the SAF folder picker, push a local-source fixture), and keep the built APK's identity straight (debug keystore vs ANDROID_USER_HOME, commit-count versionName, hash-verified release assets, docked bottom-bar insets). Use when a fresh install lacks the state a screenshot needs, when adb install fails with INSTALL_FAILED_UPDATE_INCOMPATIBLE, or before publishing an APK whose versionName counts commits."
---

# Android emulator: state seeding for screenshots + APK identity

Companion to `nixos-agp-emulator-screenshot-loop` (which covers the dev shell, the aapt2 override, headless boot and screenshot capture). This one covers what comes after: making the interesting screens *exist*, and not fooling yourself about which binary is on the device.

Measured on a Komikku (Mihon/TachiyomiSY fork) debug build, Android 16 x86_64 AVD, 1080x2400 @ 420 dpi, 2026-09-21.

## APK identity traps

### The debug signature follows the Android user home
AGP puts `debug.keystore` under `$ANDROID_USER_HOME` (default `$HOME/.android`). Exporting `ANDROID_USER_HOME` in a dev shell — tempting to keep emulator data off `$HOME` — makes the next build sign with a **fresh** key:

```
adb: failed to install …: INSTALL_FAILED_UPDATE_INCOMPATIBLE: Existing package app.example.dev
signatures do not match newer version; ignoring!
```

- Keep `ANDROID_AVD_HOME` (that is all `avdmanager`/`emulator` need). Do **not** override `ANDROID_USER_HOME`.
- Publishing consequence: a released APK and every later rebuild must share one signing identity, or the published file can never update in place.
- A failed install leaves the **old** build running, so any measurement taken afterwards describes the old artifact. Prove which build is live before concluding anything:
  `adb shell dumpsys package <id> | sed -n '/versionName/p;/lastUpdateTime/p'`
- Read install errors properly: `adb install` prints `Performing Streamed Install` and the reason on stderr (Bun's `$` hides stderr — wrap in `sh -c '… 2>&1'`). Fallbacks that print the code with less plumbing:
  `adb push <apk> /data/local/tmp/app.apk && adb shell pm install -r /data/local/tmp/app.apk`
  `adb install --no-streaming -r <apk>`

### versionName is the commit count
Mihon-family debug variants use `versionNameSuffix = "-${getCommitCount()}"`, i.e. `git rev-list --count HEAD`. Every commit made after publishing renames the artifact (1.14.1-10626 → -10629 → -10631 in one session).

- Read the truth from `app/build/outputs/apk/debug/output-metadata.json` (`elements[0].versionName`) or `aapt2 dump badging <apk>` — never from memory or from an earlier build.
- `gh release upload --clobber` does not remove **renamed** assets. Delete the old names explicitly, or the release offers two builds and the buggy one keeps the friendlier name:
  `gh release delete-asset <tag> <name> --yes`

### Prove the artifact, not the intention
Download the published asset and hash it against the local build:

```bash
gh release download <tag> --repo <owner>/<repo> --pattern '*arm64*' --dir /tmp/relcheck --clobber
sha256sum /tmp/relcheck/*.apk app/build/outputs/apk/debug/app-arm64-v8a-debug.apk
```

Equal file sizes are not equal bytes: a rebuilt APK can differ at the same size (and two screenshots' worth of code can leave the size identical while the digest changes).

## Seeding state

### Bypass a first-run wizard
Mihon/Komikku gate the wizard on `BasePreferences.shownOnboardingFlow()`, an app-state key `onboarding_complete` in `PreferenceManager.getDefaultSharedPreferences` with prefix `__APP_STATE_`. The storage step blocks on a SAF folder pick, so tapping *Next* forever changes nothing (12 taps left the same screen).

Either drive the picker (below), or skip it: force-stop, push an XML containing
`<boolean name="__APP_STATE_onboarding_complete" value="true"/>` to `/data/local/tmp`,
`adb shell run-as <id> cp /data/local/tmp/prefs.xml shared_prefs/<id>_preferences.xml` (works on a debug build), then start the launcher activity. The store caches on construction, so restart the app.

### Drive the SAF folder picker (DocumentsUI)
1. Tap the button by **exact** text. A regex like `/select a folder/i` also matches the descriptive paragraph above it; a tap sized from that node hits the description.
2. The storage root is refused ("Can't use this folder"). Use `New folder` (content-desc `New folder`), focus the `EditText`, `input text <Name>`, `OK`.
3. Then `USE THIS FOLDER`, then `ALLOW` on the system dialog.

### A local-source fixture (no extension, no network)
Komikku/Mihon's local source needs a folder per manga, a folder per chapter, images inside:

```bash
adb push /tmp/local/. /sdcard/<storage>/local/     # /tmp/local/<Manga>/<Chapter>/001.png
```

The source then lists the manga under Browse → Local source. This is the cheapest way to reach the manga detail, chapter selection and the read button.

## Driving the UI
- Resolve the SDK once and call the absolute `adb` path; a `nix-shell --run` per step costs seconds each.
- `uiautomator dump` + `adb pull` gives real-pixel `bounds`; tap the centre. Never read coordinates off a scaled vision view of the PNG.
- Long press: `adb shell input swipe X Y X Y 900`.
- A screenshot in the tens of KB or more means something rendered; a blank screen still writes a file.
- **Assert the screen before acting.** A stale dump makes taps land on the wrong surface: a `BACK` meant to clear a selection popped the screen instead, and the next capture silently showed the wrong screen.
- Batch the flow into one eval cell and print each step (the 30 s default cell deadline kills long loops — pass a larger `timeout`).

## Fixture rules for Mihon-family screens
- The read FAB renders only with an **unread** chapter: `isFABVisible = chapters.any { !it.chapter.read } && !isAnySelected`.
- A read chapter is what makes the read button's *trailing* half (or "Resume" instead of "Start") appear. With one chapter those two conditions are mutually exclusive — **seed at least two chapters**.
- Opening a chapter does not mark it read; completion does (`updateChapterProgressOnComplete`). Mark it read from the chapter-selection toolbar instead, which doubles as the detail-toolbar capture.
- The detail action menu appears only while a chapter **is selected**, and that same selection hides the FAB. Clear the selection before capturing the FAB.
- A rail-vs-bar navigation change needs no content: rotate or resize for the ≥ 600 dp width class.
- To evidence a label-visibility change, set the preference to the state that was broken (e.g. labels off) — the default state renders the same pixels before and after the fix.
- Capture the light/dark pair (`adb shell cmd uimode night no|yes`) when the PR template asks about base themes.

## Docked bottom bars and navigation-bar insets
`presentation-core/.../material/Scaffold.kt` places the bottom bar flush at `layoutHeight - bottomBarHeight` and applies no bottom inset to it, so **each bar must inset itself**. M3's `NavigationBar` does it internally; `HorizontalFloatingToolbar` does not, and has no `windowInsets` parameter.

Symptom: bar buttons at y ≈ 2317 on a 1080x2400 device while the navigation bar starts at y = 2274 (bottom inset 126 px). The icons look clipped, and taps land on the system bar (the app goes Home).

- Measure, do not assume: `adb shell dumpsys window displays` prints
  `InsetsSource … type=navigationBars frame=[0,2274][1080,2400] … bottom=126`.
- Fix once in the wrapper: `.windowInsetsPadding(WindowInsets.navigationBars.only(WindowInsetsSides.Bottom))`.
- If the fix appears not to work, first confirm the *new* artifact is installed (section above); a 10-minute re-measurement loop was spent on a build that had never installed.
