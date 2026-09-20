---
name: cargo-ndk-rust-cli-android-emulator
description: "Cross-compile a Rust CLI (e.g. jj) as an Android executable with cargo-ndk inside a nix dev shell, then prove it on an emulator: the -o cdylib-only copy failure that masks a successful build, --platform vs -p, dev-shell PATH traps, readelf/strip recipe, on-device runtime prerequisites (TMPDIR/HOME/config identity, missing git binary), and the APK side — packaging the binary as jniLibs/abi/lib*.so, the extractNativeLibs/useLegacyPackaging flag that decides whether an executable file even exists on disk, its mode and SELinux context, the SELinux block on exec from app storage, and a Gradle-free APK build to vary that flag."
---

# Cross-compile a Rust CLI for Android and prove it on an emulator

Use when a project must ship a Rust **executable** (not a cdylib) inside an APK as
`jniLibs/<abi>/lib<name>.so`, i.e. exec'd from the installer-extracted path. Verified
2026-09-18 building jj 0.45.1 for `arm64-v8a` + `x86_64` in the jjsync dev shell; the same
shape applies to any cargo workspace. The extraction/exec half was measured 2026-09-19 (see
the last section).

## Build

```sh
# writable source copy (nix store source paths are read-only; cargo needs to write)
cp -r /nix/store/<hash>-source /tmp/proj-src && chmod -R u+w /tmp/proj-src
cd /tmp/proj-src

# one cargo per target dir, or they block on the target-dir lock; run both async
nix develop /abs/path/to/project -c bash -c \
  'CARGO_TARGET_DIR=/tmp/tgt-arm64 cargo ndk -t arm64-v8a --platform 21 \
     build --release --locked --bin <bin> -j 6'
nix develop /abs/path/to/project -c bash -c \
  'CARGO_TARGET_DIR=/tmp/tgt-x86_64 cargo ndk -t x86_64 --platform 21 \
     build --release --locked --bin <bin> -j 6'

# stage under the name the APK ships
install -D -m755 /tmp/tgt-arm64/aarch64-linux-android/release/<bin> jniLibs/arm64-v8a/lib<name>.so
install -D -m755 /tmp/tgt-x86_64/x86_64-linux-android/release/<bin> jniLibs/x86_64/lib<name>.so
```

`-t arm64-v8a` → `aarch64-linux-android`; `-t x86_64` → `x86_64-linux-android`. `--platform`
must match the app's `minSdk` (cargo-ndk's default is 21). Add `--no-default-features
--features <needed>` to drop desktop-only features (for jj: `--no-default-features --features
git` drops `watchman` + `tokio` for ~4%).

## Traps (each cost real time)

- **`cargo-ndk -p` is `--package`, not `--platform`.** `-p 21` panics with
  `unknown package: 21` and dumps the entire environment to the log.
- **Never pass `-o <dir>` when the target is a binary.** cargo-ndk's copy step handles
  cdylibs only and exits 1 with `No usable artifacts produced by cargo / Did you set the
  crate-type in Cargo.toml to include 'cdylib'?` — *after* printing `Finished release
  profile`. It reads like a build failure; the binary is already at
  `$CARGO_TARGET_DIR/<ndk-target>/release/<bin>`. Stage it yourself.
- **Always give `nix develop` the flake path, and use `bash -c` not `bash -lc`.** From inside
  the source tree a bare `nix develop` picks up *that project's own* `flake.nix` (wrong
  toolchain, no cargo-ndk → `no such command: ndk`), and `bash -lc` re-sources
  `/etc/profile`, which drops the dev-shell `PATH`.
- **Build scripts may shell out to host tools** (jj's `cli/build.rs` runs `jj`/`git` for the
  version string). A source copy with no `.git`/`.jj` degrades cleanly to the plain crate
  version; pin it explicitly if the project offers an env override.
- Check whether `protoc` is needed before adding it: generated protobuf modules are often
  committed and the generator crate is a standalone, not a build-dependency.
- If the native surface is small, suss it out from the lockfile instead of rebuilding:
  absent `openssl-sys`/`curl-sys`/`libssh2-sys`/`libz-sys` (gix `default-features = false` +
  `max-performance-safe` resolves to pure-Rust `zlib-rs`) means **no C library to
  cross-compile**; the only C is usually mimalloc, built by `cc` through the NDK clang. The
  flake's `NIX_CFLAGS_COMPILE`/`NIX_LDFLAGS` never reach the NDK clang, so check hermeticity
  by grepping the binary for `/nix/store` (expect 0) and `readelf -d ... | grep -i rpath`
  (expect nothing) rather than trusting the env.

## Inspect the artifacts (in the dev shell)

```sh
readelf -h BIN | grep -E 'Class|Machine|Type'      # ELF64, DYN (PIE), AArch64 / X86-64
readelf -l BIN | grep -i interpreter               # /system/bin/linker64 == real Android ELF
readelf -d BIN | grep -E 'NEEDED|RPATH|RUNPATH'    # Rust std android needs libc.so libdl.so libm.so
file BIN                                           # "... for Android 21, built by NDK r29 ..."
$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip --strip-all COPY
strings BIN | grep -c /nix/store                   # 0 = hermetic
```

Measure both as-built and stripped: Rust's `strip = "debuginfo"` keeps the symbol table, so
`llvm-strip --strip-all` is the single biggest size lever (~20-30%).

## Prove it on the emulator

Boot headless (androidenv's `run-test-emulator`; it exits after `ready` and leaves qemu
running, so a plain async bash job suffices when the hub broker is down):

```sh
NIX_ANDROID_EMULATOR_FLAGS="-no-window -no-audio -gpu swiftshader_indirect -no-snapshot -no-metrics" \
  run-test-emulator          # look for "ready"; check `adb devices` rather than a piped log
adb push BIN /data/local/tmp/<bin> && adb shell 'chmod 755 ...; ... --version'
```

**Pin the device on every `adb` call.** A leftover AVD from an earlier session answers on the
next free port (an earlier one held `emulator-5554`, the fresh one took `emulator-5556`), so
`adb devices` can list two identical images and an unpinned install lands on whichever adb
picks. Confirm the serial by port owner — `ss -ltnp | grep 555` maps port to qemu pid, `ps`
pids to start time — then pass `-s <serial>` everywhere, and let the probe report
`Build.FINGERPRINT` plus `Build.SUPPORTED_ABIS` so the evidence names its own image.

Write the device script to a file, `adb push` it, run with `sh` — quoting survives
`adb shell` + `nix develop bash -c` layers far better than inline one-liners.

Runtime prerequisites to test for any bundled CLI, using the app's own shape:

- **`TMPDIR`** — Android's `std::env::temp_dir()` returns `TMPDIR`, else the app cache dir
  (Android 13+ in the app namespace), else `/data/local/tmp`, which an app cannot write. Test
  both `TMPDIR` unset and `TMPDIR=/nonexistent-dir`: many CLIs write temp files beside the
  repo, not in the global temp dir, which downgrades this from requirement to guardrail.
- **`HOME` / `XDG_CONFIG_HOME`** — point at app-private dirs. Without them most CLIs warn and
  continue with no config file (that is the passing case to record, not a failure).
- **Identity/config without files** — prefer a repeatable `--config KEY=VALUE` flag over
  writing config files; check the real spelling (`--config-toml` does not exist in jj 0.45.1).
  Author identity is baked at commit time, so test by creating a *new* commit and reading it
  back, never by re-reading an existing one.
- **`-R <path>` vs cwd** — many CLIs accept `-R <existing repo>` from anywhere but refuse to
  *create* a repo that way; creation needs cwd = target or a positional destination.
- **External binaries the CLI shells out to.** Grep the source for spawn sites and then prove
  the split on-device: for jj only remote paths need `git` (`clone`/`fetch`/`push`, plus
  `util gc` → `git gc`), all failing with `Could not execute the git process, found in the OS
  path 'git'` (`Caused by: No such file or directory (os error 2)`), while `git init
  --colocate`, `status`, `describe`, `bookmark`, `log`, `op log` and `import`/`export` never
  touch it (colocation writes `.git/refs/heads/main` itself via gix). A CLI config knob
  (`git.executable-path`) is the escape hatch if a binary is ever bundled.

## Extraction and exec: the flag decides, the layout does not

Measured 2026-09-19 on an API 36 (Android 16) x86_64 AOSP emulator with jj 0.45.1 in both
ABIs, by an app that reports its own filesystem and exec facts. Full evidence:
`cernoh/jjsync` issue 5, `.design/research/jni-exec.md`. `push`-and-run from
`/data/local/tmp` proves nothing here — that path is shell-owned and always executable.

- **`android:extractNativeLibs="true"` is required.** The installer then writes
  `<nativeLibraryDir>/lib<name>.so`: mode `555` (`-r-xr-xr-x`), owner `system:system`,
  SELinux context `u:object_r:apk_data_file:s0`; only the device ABI is extracted; and the
  app process (`u:r:untrusted_app`) executes it and runs the CLI normally. Omitting the
  attribute behaves the same — the *platform* default is extraction.
- **The AGP/Flutter default extracts nothing.** AGP packages native libraries uncompressed
  and page-aligned, which it expresses as `extractNativeLibs="false"`; `<nativeLibraryDir>`
  still exists and is readable but is **empty** (`list(): []`, `total 0`) — there is no file
  to execute at all. Never infer extraction from the directory; list it and `stat` the file.
- **The fix is one Gradle line**, and it is invisible in a manifest a build tool generates:

  ```kotlin
  android { packaging { jniLibs { useLegacyPackaging = true } } }
  ```

  Per the AGP DSL, `useLegacyPackaging` "replaces the manifest attribute
  `extractNativeLibs`"; null means "uncompressed and page-aligned when minSdk >= 23". Legacy
  packaging also *deflates* the payload inside the APK (46.1 MB stored vs 19.0 MB deflated
  for both ABIs here) and costs the extracted copy per device ABI (24.8 MB x86_64, 21.3 MB
  arm64) — report bytes, not `df`/`du` deltas, which on an emulator under-reported a 46.1 MB
  APK as ~30.5 MB.
- **The copy-to-app-storage workaround is dead above targetSdk 28.** Copying the entry out of
  the APK (it is `STORED`, so `ZipFile` reads it) or out of `assets/`, then `chmod 0700`,
  yields a file whose `File.canExecute()` and `chmod` both report success — and the exec
  still fails with `IOException: Cannot run program ...: error=13, Permission denied`, i.e.
  `avc: denied { execute_no_trans } ... tcontext=u:object_r:app_data_file:s0`. At targetSdk
  28 the same route works because the domain becomes `u:r:untrusted_app_27`, which is not
  usable for a store release. **`canExecute()`/`chmod` are not an exec test; run the binary.**
- Treat a missing extracted file as a hard, explicit error in the app: the only honest
  pre-flight check is the file plus a real run.

## Build an APK without Gradle to vary one manifest attribute

Gradle is not needed to test packaging semantics, and a hand-built APK has no AGP opinion:

```sh
BT="$ANDROID_HOME/build-tools/37.0.0"; PLATFORM="$ANDROID_HOME/platforms/android-36/android.jar"
"$BT/aapt2" compile --dir res -o res.zip
"$BT/aapt2" link -o base.apk -I "$PLATFORM" --manifest AndroidManifest.xml -R res.zip --java gen
javac -nowarn -Xlint:-options -source 8 -target 8 -bootclasspath "$PLATFORM" \
  -classpath "$PLATFORM" -d classes $(find src gen -name '*.java')   # 8, not 11: -bootclasspath
"$BT/d8" --lib "$PLATFORM" --min-api 26 --output dex $(find classes -name '*.class')
cp base.apk app.apk && ( cd stage && jar -0 -u -f ../app.apk classes.dex lib assets )
"$BT/zipalign" -f -p 4 app.apk app-aligned.apk        # -p page-aligns uncompressed .so
"$BT/apksigner" sign --ks debug.keystore --ks-pass pass:android --key-pass pass:android \
  --ks-key-alias androiddebugkey --out app.apk app-aligned.apk
```

- `jar -0` stores the `.so` uncompressed (what `extractNativeLibs="false"` demands); drop the
  `-0` for compressed legacy packaging.
- Sign **after** `zipalign`; `-p` (4 KB) only matters for the uncompressed route, and 16 KB
  page-size devices need `-P 16`.
- Debug keystore: `keytool -genkeypair -keystore debug.keystore -storepass android -keypass
  android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android
  Debug,O=Android,C=US"`.
- Write the probe in Java against `android.jar` only: `java.lang.Process` collides with
  `android.os.Process` (qualify it), lambdas fail to compile at `-source 8` because the
  android.jar stub exposes no `LambdaMetafactory.metafactory`, and `d8` needs its `--output`
  directory to exist. Have the app write its report to `getExternalFilesDir(null)` so it can
  be pulled without root, and run the same binary through several manifests (`true`, `false`,
  absent, deflated) instead of trusting one build's default.

## Cleanup

`adb -s <serial> emu kill` for the AVD this session started, and remove anything pushed into
the device's `/data/local/tmp`. Do not kill an emulator whose pid predates your session —
another session may own it.
