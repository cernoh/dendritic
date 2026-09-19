---
name: nix-flutter-android-dev-shell
description: "Stand up a nix flake dev shell carrying Flutter, the Android SDK/emulator and a pinned Rust toolchain with Android targets (fail2ban for aarch64/x86_64 ABIs via cargo-ndk), and verify it. Use when a project needs one shell that builds Android APKs and cross-compiles Rust cdylibs, or when flutter doctor reports an Android toolchain problem under nix, or when cargo-ndk cannot find the NDK."
---

# Nix dev shell: Flutter + Android SDK/emulator + Rust Android cross-builds

Facts measured 2026-09-18 on x86_64-linux with nixpkgs 26.11pre-git
(rev `eaad0894`, flutter 3.47.0, jj 0.45.1, androidenv repo metadata: platforms
37.1, build-tools 37.0.0, cmdline-tools 22.0, platform-tools 37.0.1, emulator
37.1.11, NDK 29.0.14206865). Working example: `cernoh/jjsync` `flake.nix`.

## Shape

One `devShells.<system>.default`. Import nixpkgs with the androidenv gates:

```nix
pkgs = import nixpkgs {
  inherit system;
  config = { allowUnfree = true; android_sdk.accept_license = true; };
  overlays = [ rust-overlay.overlays.default ];   # only if a pinned Rust is needed
};
```

Packages: `pkgs.flutter`, `androidSdk` (= `android.androidsdk`), `android.platform-tools`,
`emulator` (= `pkgs.androidenv.emulateApp {...}`), `pkgs.jdk`,
`pkgs.cargo-ndk`, `pkgs.rust-bin.stable."<ver>".default.override { targets = [...]; }`,
`pkgs.jujutsu`/`pkgs.git` if needed, plus `pkg-config cmake ninja clang`.

Env (all four matter):

```nix
JAVA_HOME = jdk.home;                      # flutter/gradle read this, not PATH java
ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
ANDROID_SDK_ROOT = ANDROID_HOME;
ANDROID_NDK_HOME = "${ANDROID_HOME}/ndk-bundle";   # cargo-ndk reads this first
ANDROID_NDK_ROOT = "${ANDROID_HOME}/ndk-bundle";
```

## androidenv specifics

- Compose with `pkgs.androidenv.composeAndroidPackages { ... }`. Options that
  matter: `platformVersions`, `buildToolsVersions`, `cmdLineToolsVersion`,
  `platformToolsVersion`, `includeEmulator`, `includeSystemImages`,
  `systemImageTypes` (default is the four `google_apis*`; set `[ "default" ]`
  for AOSP-only), `abiVersions`, `includeNDK`, `ndkVersions`, `extraLicenses`.
- **Not every platform has every image tag.** Check before choosing
  (`repo.json` `images.<api>.<tag>` — see the query below); a tag that does not
  exist for the chosen platform is skipped, not an error, so an AVD can silently
  have no image.
- The SDK root (`libexec/android-sdk`) gets `platform-tools`, `build-tools/<v>`,
  `platforms/android-<v>`, `emulator`, `ndk/<v>` **and** a legacy `ndk-bundle`
  symlink, `system-images/`, `licenses/`; `$sdk/bin` exposes `adb`, `emulator`,
  `sdkmanager`, `avdmanager`.
- `emulateApp { name; platformVersion; abiVersion; systemImageType; deviceName; sdkExtraArgs; }`
  produces `run-test-emulator`: creates the AVD into a temp/user home, boots it,
  waits for `dev.bootcomplete`, prints `ready`. Nothing writes into the repo.
- androidenv is **unfree**, so these packages are not on cache.nixos.org: expect
  ~900 MiB of Google zips fetched and ~30 local derivations (all fixed-output or
  symlink work, no from-source compiles).

## Licenses (the usual flutter doctor failure)

`licenses/android-sdk-license` is written by default. cmdline-tools reports the
rest unaccepted, and `flutter doctor` shows `[!] Android toolchain … Some
Android licenses not accepted`. Fix in the flake, never with a manual accept:

```nix
extraLicenses = [
  "android-sdk-preview-license" "android-googletv-license"
  "android-googlexr-license"                     # cmdline-tools 22.0 wanted this one
  "android-sdk-arm-dbt-license" "google-gdk-license"
  "intel-android-extra-license" "intel-android-sysimage-license"
  "mips-android-sysimage-license"
];
```

`extraLicenses` is a **drifting pin**: each cmdline-tools bump can mint a new
license id, and the failure is only visible as a count (`N of 7 SDK package
licenses not accepted`). Name the missing id by pointing `--sdk_root` at a
writable copy of the SDK, answering `yes`, and diffing the `licenses/` dir:

```bash
mkdir -p /tmp/sdkroot && for p in "$ANDROID_HOME"/*; do ln -s "$p" /tmp/sdkroot/; done
rm /tmp/sdkroot/licenses && cp -rL "$ANDROID_HOME/licenses" /tmp/sdkroot/licenses && chmod -R u+w /tmp/sdkroot/licenses
yes y | sdkmanager --sdk_root=/tmp/sdkroot --licenses
ls /tmp/sdkroot/licenses     # the NEW file name is the missing id
```

Prove with `sdkmanager --licenses < /dev/null` → `All SDK package licenses accepted.`
and `flutter doctor -v` → `[✓] Android toolchain`.

## Pinned Rust with Android targets

nixpkgs' rustc moves ahead of a project's MSRV; get an exact release plus the
Android std libraries from rust-overlay:

```nix
rust-overlay = { url = "github:oxalica/rust-overlay"; inputs.nixpkgs.follows = "nixpkgs"; };
rust = pkgs.rust-bin.stable."1.97.1".default.override {
  targets = [ "aarch64-linux-android" "x86_64-linux-android" ];
};
```

Note the attr set: `rust-bin` comes from the **overlay**
(`overlays = [ rust-overlay.overlays.default ]` then `pkgs.rust-bin`), not from
`rust-overlay.packages.<system>.rust-bin` (that path has no `rust-bin` attr).
`.default` already carries cargo, rustfmt and clippy.

Expose nixpkgs' cross set for crates that link C code:
`legacyPackages.<system>.androidAarch64 = pkgs.pkgsCross.aarch64-android;`
(its `stdenv.hostPlatform.config` is `aarch64-unknown-linux-android`).

## Traps

- **nixpkgs' flutter asserts `NIX_AAPT2_BINARY_PATH`** when it assembles an APK
  through Gradle. `pkgs.flutter`'s wrapper sets it to nixpkgs' aapt; the
  unwrapped one does not. Always build through `pkgs.flutter`.
- **`run-test-emulator` looks hung when its output is piped** (`| tail` or a log
  file): the backgrounded emulator holds the pipe open after the script prints
  `ready`. Check `adb devices` and `adb emu kill` instead of waiting for EOF.
- `sdkmanager` warns `Observed package id 'ndk;…' in inconsistent location` for
  the `ndk-bundle` symlink. Harmless; cargo-ndk works through `ANDROID_NDK_HOME`.
- The flake's `nixConfig` is ignored unless the caller passes
  `--accept-flake-config` (nix warns `ignoring untrusted flake configuration
  setting 'substituters'`). Put `cache.nixos.org` first there anyway.
- Android Studio is not needed and its absence is not a failure; Chrome is
  `[✗]` unless the web target is in scope (set `CHROME_EXECUTABLE` if so).
- A gradle-wrapper project needs no `pkgs.gradle`: the wrapper downloads its own
  distribution.

## Verification recipe

```bash
nix develop .#default --command bash -lc '
rustc -vV | head -1
ls "$(rustc --print sysroot)/lib/rustlib"        # both android targets present
cargo ndk --version; flutter --version | head -1
flutter doctor -v | sed -n "/Android toolchain/,/^\[/p"
sdkmanager --licenses < /dev/null
NIX_ANDROID_EMULATOR_FLAGS="-no-window -no-audio -gpu swiftshader_indirect -no-snapshot" run-test-emulator
adb shell getprop ro.build.version.sdk'
```

Cross-build proof (throwaway crate outside the repo, `crate-type = ["cdylib"]`):

```bash
cargo ndk -t arm64-v8a -t x86_64 -o jniLibs build --release
file jniLibs/*/lib*.so        # expect "… for Android 21, built by NDK r29 (…)"
readelf -h jniLibs/arm64-v8a/lib*.so | grep Machine    # AArch64
readelf -h jniLibs/x86_64/lib*.so    | grep Machine    # X86-64
```

cargo-ndk's default platform level is **Android 21**; a higher `minSdk` needs
`--platform`.

Inspect versions before choosing them:

```bash
nix eval --impure --json --expr 'let r = builtins.fromJSON (builtins.readFile <repo.json from pkgs/development/mobile/androidenv>); in { latest = r.latest; tags36 = builtins.attrNames r.images."36"; }'
nix eval --impure --expr 'let a = (import <nixpkgs> {}).androidenv.androidPkgs; in builtins.attrNames a.platforms'
ni  # (use nix eval, not guesswork: platform/abi/tag availability varies per api level)
```
