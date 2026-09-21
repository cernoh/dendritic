---
name: komikku-m3e-sideload-release
description: "Ship a sideloadable debug APK of the komikku-M3E fork as a GitHub prerelease so it installs beside the official Komikku, and prove the uploaded artifact is the right build. Use when asked to publish a build for the user to download, when a release must come from an unmerged branch, or before claiming a release contains a feature."
---

# Sideload release of komikku-M3E

Repo: `cernoh/komikku-M3E`, checkout `/mnt/2tb-ext4/komikku-M3E`. Build shell: `nix-shell` in the repo root
(JDK 17, Android platform 36, build-tools 36.0.0 and 35.0.0, `AAPT2_OVERRIDE`).

## Before you create anything

1. **`master` cannot build.** It pins the dead JitPack coordinate
   `com.github.arkon.FlexibleAdapter:flexible-adapter:c8013533` in `gradle/libs.versions.toml`, and JitPack
   404s it (its own build wants `nu.studer:java-ordered-properties:1.0.1`, gone from Maven Central).
   A release therefore comes from the branch that carries the Maven Central fix
   (`eu.davidea:flexible-adapter:5.1.0`), not from `master`.
2. **Pick the commit that builds.** Use the head of the feature branch, and pass it explicitly: a release
   with no `--target` tags the default branch, which is the unbuildable state.
3. **Build the APK on that commit** (the gate is `spotlessApply` → `spotlessCheck` → `assembleDebug`), so
   the artifacts in `app/build/outputs/apk/debug/` match the tag.

## Which APK

`app/build/outputs/apk/debug/output-metadata.json` gives the identity of every split: `applicationId`,
`versionCode`, `versionName`, and one entry per ABI plus `UNIVERSAL`.

The debug build type appends `.dev` to the application ID (`app.komikku.dev`), so the build **installs
beside** the official `app.komikku` and shares no data with it. That is the whole reason a debug APK is the
right artifact to hand a user who wants both.

Attach `arm64-v8a` for a modern phone and `universal` for an unknown ABI. Name the assets with the release
name and the version so a folder of downloads stays readable, for example
`komikku-expressive-1.14.1-10626-arm64-v8a.apk`.

## Create the release

```bash
cd /mnt/2tb-ext4/komikku-M3E
SHA=$(git rev-parse HEAD)
cp app/build/outputs/apk/debug/app-arm64-v8a-debug.apk /tmp/<name>-<versionName>-arm64-v8a.apk
cp app/build/outputs/apk/debug/app-universal-debug.apk  /tmp/<name>-<versionName>-universal.apk
gh release create <name> --repo cernoh/komikku-M3E --target "$SHA" --title "<name>" \
  --prerelease --notes-file /tmp/<name>-notes.md /tmp/<name>-<versionName>-arm64-v8a.apk /tmp/<name>-<versionName>-universal.apk
```

Mark it `--prerelease` while the work is unmerged and no visual check has happened.

## Prove the uploaded artifact

Two commands, both cheap, and both catch a stale APK:

```bash
AAPT2=/nix/store/*/libexec/android-sdk/build-tools/36.0.0/aapt2
"$AAPT2" dump badging /tmp/<name>-<versionName>-arm64-v8a.apk | sed -n '1,3p;/sdkVersion/p'
unzip -p /tmp/<name>-<versionName>-arm64-v8a.apk resources.arsc \
  | tr -c '[:print:]' '\n' | sed -n '/<a string this build introduced>/p' | head -2
```

The first gives `package`, `versionCode`, `versionName`, `minSdkVersion`. The second reads a string the
build adds (a new `i18n-kmk` base string works well): if it is present, the file is the build you think it is.

Confirm the release afterwards:

```bash
gh release view <name> --repo cernoh/komikku-M3E \
  --json tagName,isPrerelease,targetCommitish,assets \
  --jq '"tag: \(.tagName) prerelease: \(.isPrerelease) target: \(.targetCommitish)", (.assets[] | "\(.name) \(.size/1024/1024|floor) MB \(.state)")'
```

## Write only what the build does

A release note is a claim, and the user installs the build to check it. Before writing that a feature is
in the release, count its call sites in the tagged tree:

```bash
# the wrapper exists?
ls presentation-core/src/main/java/tachiyomi/presentation/core/components/m3e/
# does anything call it?
grep -rn "WavyLinearProgressIndicator\|WavyCircularProgressIndicator\|ExpressiveFloatingToolbar" --include=*.kt app/src/main/java | wc -l
```

A wrapper with no call sites ships nothing. In this repo the wavy progress reached the reader page loader
(`CombinedCircularProgressIndicator`) and the selection spinner only; the download, update and migration
dialogs still render stock `LinearProgressIndicator` until the area pull requests convert them.

## Tell the user about the launcher

Both apps are labelled `Komikku` in the launcher. Distinguish them by Settings → About, which shows the
debug version name, or by the package name in App info. Say so in the release notes.
