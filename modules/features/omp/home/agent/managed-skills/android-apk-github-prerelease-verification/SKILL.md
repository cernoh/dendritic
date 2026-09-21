---
name: android-apk-github-prerelease-verification
description: "Publish and verify a sideloadable Android prerelease from a GitHub fork (work-in-progress branch, NixOS host): variant applicationId for side-by-side install, per-commit versionName, stale release assets after a rename, gh release target_commitish vs tag ref, and the hash/class-level proofs that the uploaded binary really contains the fix."
---

Publish a work-in-progress Android build as a downloadable GitHub prerelease, and prove the artifact contains the fix. Use when a user asks for a release they can install beside the original app ("download it alongside the original"), or after a fix must reach an already-published APK.

## 1. Pick a variant that installs beside the original

Read `buildTypes` for `applicationIdSuffix`. Mihon-lineage apps use `debug` → `.dev`, `releaseTest` → `.rt`, `foss` → `.foss`, `preview` → `.beta`. The suffixed package installs beside the original and shares no data with it.

Confirm from the built artifact, never from the source alone:

```bash
aapt2 dump badging app/build/outputs/apk/debug/app-arm64-v8a-debug.apk | sed -n '1,3p;/sdkVersion/p'
# package: name='app.komikku.dev' versionCode='81' versionName='1.14.1-10629' ...
# minSdkVersion:'26'  targetSdkVersion:'36'
```

Same `applicationId` as the original means it *replaces* it, or fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` when the signing key differs.

Warn the user about the launcher: the debug variant usually keeps the upstream label, so both apps read identically. Distinguish them by Settings → About (the suffixed version string) or App info (package name).

## 2. Build on a host with no JDK or SDK

A `shell.nix` with `pkgs.jdk17` plus `androidenv.composeAndroidPackages` gives `JAVA_HOME`/`ANDROID_HOME`. The AGP-downloaded `aapt2` cannot start on NixOS, so pass the SDK's binary through:

```bash
GRADLE_USER_HOME=/mnt/big-disk/.gradle-<project> nix-shell --run \
  'cd <repo> && ./gradlew :app:assembleDebug -Pandroid.aapt2FromMavenOverride=$AAPT2_OVERRIDE --console=plain'
```

Include every build-tools version the project asks for (AGP may request an older one than the platform's). Put `GRADLE_USER_HOME` on a large disk; the first build downloads about 1 GB.

## 3. Read the build's identity from its output

`app/build/outputs/apk/debug/output-metadata.json` holds `applicationId`, `versionCode`, `versionName` and the per-ABI file names. Use it instead of guessing file names.

Mihon-lineage apps append `versionNameSuffix = "-${getCommitCount()}"`, where `getCommitCount()` is `git rev-list --count HEAD`. **Any new commit changes the version string.** Re-read it after every rebuild; a release asset name and a notes line quoting the old string go stale silently.

## 4. Create the release

```bash
gh release create <tag> --repo <owner>/<repo> --target <sha-or-branch> \
  --title "<tag>" --prerelease --notes-file /tmp/notes.md \
  <arm64 apk> <universal apk>
```

- `--target` is not optional: without it the release tags the default branch, which for a fork in mid-work often does not build at all.
- Attach the universal APK plus the common `arm64-v8a` slice; universal covers an unknown device.
- `--prerelease` for unmerged or visually unverified work.

## 5. Traps when the release must be corrected

- **Renamed assets leave the old ones attached.** `gh release upload --clobber` replaces same-named assets only, so after a rename the page offers both the buggy and the fixed build. Delete explicitly: `gh release delete-asset <tag> <old-name> --yes`.
- **`gh release edit` has no `--target`.** The stored `target_commitish` keeps its creation value even after the tag ref moves. Repoint it with the API, using a *branch name* (a raw sha is rejected with `422`):

  `gh api -X PATCH repos/<o>/<r>/releases/<id> -f target_commitish=<branch>`
- **The tag ref is the authority**, not `target_commitish`:

  `gh api repos/<o>/<r>/git/ref/tags/<tag> --jq .object.sha`
- **Moving a published tag:** `git tag -f <tag> <sha> && git push -f origin refs/tags/<tag>`.
- Keep the tag, the assets, the notes' version line and the notes' source commit consistent; a mismatch is a lie a reviewer will find.

## 6. Proof recipes (do not skip these)

- **The uploaded asset is the build you made** — download and compare hashes. Equal *sizes* prove nothing; two builds from the same tree can be byte-size-equal while differing in content.

  ```bash
  gh release download <tag> --repo <o>/<r> --pattern '*arm64-v8a*' --dir /tmp/relcheck --clobber
  sha256sum /tmp/relcheck/*.apk app/build/outputs/apk/debug/app-arm64-v8a-debug.apk
  ```
- **A code fix reached the dex** — string-grep the specific compiled class, not the APK. A symbol that other files also call appears in the dex regardless, so an APK-wide grep proves nothing.

  ```bash
  strings app/build/tmp/kotlin-classes/debug/<pkg>/<Screen>Kt.class | sed -n '/BulkSelectionToolbar/p'
  ```
- **A new string resource shipped** — `unzip -p <apk> resources.arsc | tr -c '[:print:]' '\n' | sed -n '/<new text>/p'`.

## 7. Report honestly

State the install identity (`applicationId`, version, minSdk, signing), which artifact to pick, what the release does *not* do, and what the verification was. Compile and formatting gates do not see the interface: say that the first visual check is the install itself unless screenshots exist.
