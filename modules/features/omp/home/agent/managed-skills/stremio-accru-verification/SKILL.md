---
name: stremio-accru-verification
description: Verify stremio-accru (cargo + vitest + deno + act + desktop-player) is working
---

# Stremio Accru Verification

Repeatable 8/8 verification covering PR #28 desktop-player (libmpv2) gap where default `cargo check` skips it.

## Prerequisites
- `nix develop` (rustc 1.98, deno 2.9.5, node 22) — provides `cargo`, `npx`, `deno`, `PKG_CONFIG_PATH` for `pkgs.mpv`/`webkitgtk_4_1`
- On `main` synced (`07f1374` includes f0c0b96 44 Rust + 27 Vitest and 0fdd369 Deno gates)

## 1. Local 8/8 (mirrors CI + covers hidden feature)
```bash
nix develop -c bash scripts/verify.sh
# 1/8 cargo check
# 2/8 cargo test (44)
# 3/8 svelte-kit sync
# 4/8 vite build (adapter-static)
# 5/8 svelte-check
# 6/8 vitest run (27: config 8, cache 8, catalog-service 5, tauri-mock 6 via @tauri-apps/api/mocks)
# 7/8 deno fmt --check (38 files, 80-col markdown)
# 8/8 deno lint (4 files, ban-ts-comment needs `: description`, no-window/require-await ignores)
```

## 2. Desktop-player feature (not in CI/verify.sh default)
```bash
nix develop -c bash -c 'cargo check --manifest-path src-tauri/Cargo.toml --features desktop-player'
nix develop -c bash -c 'cargo test --manifest-path src-tauri/Cargo.toml --features desktop-player'
# verifies 400+ lines desktop.rs + build.rs vendoring with libmpv2 pkg-config; should finish ~5.6s Checking
```

## 3. Local CI via act
```bash
pwd # /mnt/2tb-storage/stremio-accru
git branch --show-current # main
act -l # ci/check ci.yml
act push -n -W .github/workflows/ci.yml -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64 # dry
act push -W .github/workflows/ci.yml -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64
# Expect: Cargo check ✔ 47s, Cargo fmt ❌ cargo-fmt not installed in catthehacker image — environment-limited, ignore (host nix cargo fmt ✔)
```

## References
- Tauri docs: https://v2.tauri.app/develop/tests/ + /develop/tests/mocking/ (mockIPC/mockWindows/shouldMockEvents, randomFillSync)
- CI: `.github/workflows/ci.yml` (cargo check/fmt, setup-node, SvelteKit sync, build, svelte-check, deno fmt/lint)
- Worktree: ../stremio-accru-progtests feat/28-programmatic-tests (absolute write needed, relative xd:// edits lost)
