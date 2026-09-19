---
name: cargo-ndk-rust-cli-android-emulator
description: "Cross-compile a Rust CLI (e.g. jj) as an Android executable with cargo-ndk inside a nix dev shell, then prove it on an emulator: the -o cdylib-only copy failure that masks a successful build, --platform vs -p, dev-shell PATH traps, readelf/strip recipe, and on-device runtime prerequisites (TMPDIR/HOME/config identity, missing git binary)."
---

# Cross-compile a Rust CLI for Android and prove it on an emulator

Use when a project must ship a Rust **executable** (not a cdylib) inside an APK as
`jniLibs/<abi>/lib<name>.so`, i.e. exec'd from the installer-extracted path. Verified
2026-09-18 building jj 0.45.1 for `arm64-v8a` + `x86_64` in the jjsync dev shell; the same
shape applies to any cargo workspace.

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

Leave extraction-permission proofs (exec from `jniLibs/<abi>/lib*.so` after install) to the
ticket that owns them; this recipe only proves the binary is a correct Android artifact whose
runtime dependencies are satisfied.
