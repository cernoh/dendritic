---
name: nixos-agp-emulator-screenshot-loop
description: "Build an Android app with AGP on NixOS and prove a screen change with a headless emulator screenshot: the aapt2 override that must be a Gradle property, the build-tools 36 requirement, nixpkgs androidenv SDK composition, KVM/headless emulator flags, and the splits-vs-release-bundle defect. Use when building or screenshotting an Android app on NixOS, when aapt2 daemon startup fails, or when an emulator must run headless."
---

# Android build + headless emulator screenshot loop on NixOS

Proven on Sealplus (AGP 9.2.1, Gradle 9.5.1, compileSdk 37, Java 21) on an x86_64 NixOS host with `/dev/kvm` and no display, 2026-09-18.

Working reference: `docs/android-build-and-screenshot.md`, `shell.nix` and `scripts/android-{build,emulator,screenshot}.sh` in cernoh/Sealplus on branch `task/ticket-06-build-screenshot-loop` (PR #25).

## Dev shell

Use nixpkgs `androidenv.composeAndroidPackages`, not a downloaded SDK. A `shell.nix` with `builtins.getFlake "nixpkgs"` works under `nix-shell` (impure eval).

```nix
pkgs = import (builtins.getFlake "nixpkgs") {
  system = builtins.currentSystem;
  config = { android_sdk.accept_license = true; allowUnfree = true; };
};
androidComposition = pkgs.androidenv.composeAndroidPackages {
  cmdLineToolsVersion = "latest";
  platformToolsVersion = "latest";
  buildToolsVersions = [ "37.0.0" "36.0.0" ];   # BOTH: see trap 2
  platformVersions = [ "37" "36" ];
  includeEmulator = true;
  includeSystemImages = true;
  systemImageTypes = [ "default" ];
  abiVersions = [ "x86_64" ];
  includeSources = false; includeNDK = false; includeCmake = false;
};
```

`config.android_sdk.accept_license = true` (or `NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE=1`) is required. `compose-android-packages.nix` makes `androidsdk`'s `postInstall` throw the license text when `licenseAccepted` is false. Note the failure mode: the store can already hold every individual component (`android-sdk-platforms-37.0`, `android-sdk-build-tools-37.0.0`, `android-sdk-emulator-*`, `android-sdk-system-image-*`, `openjdk-21`) while the **composed** `androidsdk` output does not exist yet. Seeing the components in the store is therefore not evidence that the shell will work: the composition is a separate derivation and will be built on the first entry.

**The composition adds nothing to `PATH`.** Add the tools in `shellHook`; the `cmdline-tools` directory is named after the archive version (`22.0`), so glob it:

```bash
for dir in "$ANDROID_HOME"/cmdline-tools/*/bin "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator"; do
  PATH="$dir:$PATH"
done
```

## Trap 1: AGP's Maven aapt2 cannot start on NixOS — and the fix must be `-P`

Symptom, in `:app:processXxxResources`:

```
AAPT2 aapt2-9.2.1-15009934-linux Daemon #0: Daemon startup failed
```

With `--info` the cause is explicit:

```
Could not start dynamically linked executable: .../aapt2-9.2.1-15009934-linux/aapt2
NixOS cannot run dynamically linked executables intended for generic linux environments out of the box.
```

AGP downloads its own `aapt2` from Google Maven and runs it as a daemon. Fix: point it at the SDK's aapt2.

- **`-Pandroid.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/<ver>/aapt2` works.**
- **An `android.aapt2FromMavenOverride=` line in `local.properties` does NOT work.** Measured: with the entry in `local.properties` and no `-P` flag, the same daemon failure returns. AGP reads that setting only from a Gradle property (command line `-P`, or `gradle.properties`).

Corollary for `shell.nix`: put the override in an `AAPT2_OVERRIDE` variable only as a record of which binary to use. It does nothing by itself.

## Trap 2: AGP resolves build-tools it does not declare

`compileSdk = 37` does not stop AGP resolving `build-tools;36.0.0`. With only 37.0.0 in the shell:

```
Failed to install the following SDK components:
    build-tools;36.0.0 Android SDK Build-Tools 36
  The SDK directory is not writable (/nix/store/...-androidsdk/libexec/android-sdk)
```

The store is read-only, so AGP cannot self-install. List **both** versions in `buildToolsVersions`.

## Trap 3: ABI splits and the release bundle cannot build together (AGP 9.2.1)

```
Execution failed for task ':app:buildGenericReleasePreBundle'.
> Multiple shrunk-resources files found in directory '.../minifyGenericReleaseWithR8'
Please disable building multiple APKs when building an Android app bundle.
```

`buildGenericRelease` fails while `splits { abi { isEnable = true } }` is on. `buildGenericRelease -PnoSplits` and `assembleGenericRelease -PnoSplits` both succeed. Debug variants are unaffected. Check whether the project's CI runs the release task without the flag before blaming the host.

## Trap 4: `local.properties` and the SDK path

The SDK is a Nix store path, so it changes whenever `shell.nix` changes. Never commit `local.properties`; write it from `$ANDROID_HOME` on every build. A stale `sdk.dir` silently breaks the build.

## Headless emulator

`avdmanager create avd` needs a writable AVD home. It prints `Error: Could not load devices from .../devices.xml` because the nixpkgs system image ships no `devices.xml`; this is noise, and the `--device` profile still lands in `config.ini`.

```bash
export ANDROID_AVD_HOME=<writable>/avd ANDROID_USER_HOME=<writable>
avdmanager --silent create avd -n <name> \
  -k "system-images;android-36;default;x86_64" --device pixel_6 --force

setsid nohup emulator -avd <name> -port 5554 \
  -no-window -no-audio -no-boot-anim -no-snapshot -no-metrics \
  -gpu swiftshader_indirect > /tmp/emu.log 2>&1 < /dev/null &

adb -s emulator-5554 wait-for-device
until [ "$(adb -s emulator-5554 shell getprop sys.boot_completed | tr -d '\r')" = "1" ]; do sleep 3; done
```

- `emulator -accel-check` must print `KVM (version 12) is installed and usable.`
- `setsid nohup` is what makes the emulator outlive the shell.
- Turn animations off for stable captures: `settings put global {window_animation,transition_animation,animator_duration}_scale 0`.
- Cold boot to `sys.boot_completed=1` measured 163 s on a 16-core host with swiftshader.
- `emulator` logs `ERROR | detected a hanging thread 'QEMU2 CPU0 thread'. No response for ... ms` while the guest boots under software rendering. It is not fatal.

## Screenshot

```bash
adb -s emulator-5554 install -r -g <path>/<abi>.apk
adb -s emulator-5554 shell am start -n <applicationId>/<launcherActivity>
sleep 20                      # software rendering: splash holds ~10 s
adb -s emulator-5554 exec-out screencap -p > /tmp/screen.png
```

- Install the APK for the emulator ABI (x86_64), not another split.
- A debug build with `applicationIdSuffix ".debug"` installs as `<applicationId>.debug`.
- A blank screenshot still writes a file. Check the size: a rendered screen is tens of KB and up.
- If SystemUI raises an "isn't responding" dialog under software rendering, the app is usually fine: dismiss and capture again. Print the app process log (`logcat -d --pid $(pidof <pkg>)`) to tell an ANR from a crash.
- A first launch after a fresh install can open an app dialog (e.g. a battery-optimisation prompt) over the real screen on every launch until dismissed.
- `/data/data/<pkg>` is not readable by the `shell` user: use `adb root` or `adb shell run-as <pkg>`.

### Tap coordinates: never read them off a scaled image

`screencap` writes real pixels (e.g. 1080x2400) and `input tap X Y` uses that space, but a vision read of the PNG usually reports the **displayed**, scaled-down size. A coordinate read from that view lands on the wrong element unless it is multiplied by the scale factor. This cost two wrong taps in a row on 2026-09-18, and one of the wrong values was written into a recipe document before it was caught.

Working method:

```bash
adb -s emulator-5554 shell uiautomator dump /sdcard/ui.xml
adb -s emulator-5554 pull /sdcard/ui.xml /tmp/ui.xml   # bounds="[x1,y1][x2,y2]" in real pixels
```

Take the centre of the target's `bounds`, or use the vision read only to choose the element and `uiautomator` to place the tap. If a tap appears to do nothing, the coordinate is wrong far more often than the UI is stuck.

## Prove the app, not just its startup

For apps that bundle native binaries as `.so` plus packed `.zip.so` archives, the payload unpacks **on first launch**, not at install, into the app's `no_backup/` directory. Do not reverse-engineer the extraction layout with `run-as` shell probes: the library sets its own exec bits and runs its tool through its bundled interpreter, so a direct exec fails with `Permission denied` even when the payload is healthy.

Use the app's own call path instead. A Settings screen that renders a version obtained from the binary (Sealplus: Settings → General calls `YoutubeDL.getInstance().version(context)`, `GeneralDownloadPreferences.kt:191`) proves the payload initialised on device from one adb tap sequence, and gives a second real screen for the loop. A completed real workload plus the output file on disk proves more still.

## Measuring build times honestly

The configuration cache makes a genuinely unchanged build ~5 s. Two ways to measure a false incremental time:

- **A no-op build.** `Configuration cache entry reused.` with a handful of executed tasks is not an incremental compile.
- **Re-applying the *identical* edit.** Gradle compares content hashes, so restoring the exact byte content it compiled last time leaves `compileXxxKotlin UP-TO-DATE` and measures a no-op, not an incremental compile. When probing incremental speed, change the string to something you have not compiled before (a second comment line), and confirm `:app:compileGenericDebugKotlin` runs rather than reporting `UP-TO-DATE`.

Verified times on a 16-core host, warm caches, one Kotlin file changed to novel content: first build with dependency downloads 346 s; clean build after `./gradlew clean` 94 s; incremental after one source file 12 s; no-op 5 s; emulator cold boot 163 s.
