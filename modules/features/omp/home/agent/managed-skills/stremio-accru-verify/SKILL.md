---
name: stremio-accru-verify
description: Verify stremio-accru on NixOS via 8-step scripts/verify.sh (cargo check/test + svelte-kit sync + vite build + svelte-check + vitest + deno fmt/lint)
---

# Stremio-Accru Verify

Run the 8-step CI-mirroring verification on NixOS. Requires `nix develop` (cargo, deno, node, webkitgtk, mpv).

```bash
git checkout main && git pull --ff-only
nix develop -c bash scripts/verify.sh
# or via background hub:
# hub start verify nix develop -c bash scripts/verify.sh; hub wait verify --for exit
```

Steps (8/8 must pass):
1. `cargo check --manifest-path src-tauri/Cargo.toml`
2. `cargo test --manifest-path src-tauri/Cargo.toml` — 44 Rust (player/skip, tracks subs_lang fix, hdr, svp, thumbnails, state, backend, core/runtime, config/portable)
3. `npx svelte-kit sync`
4. `npm run build` (vite + adapter-static)
5. `npm run check` (svelte-check)
6. `npx vitest run` — 27 Vitest jsdom + @tauri-apps/api/mocks (config, cache, catalog-service, tauri-mock)
7. `deno fmt --check` — 38 files, markdown 80-col; run `deno fmt` to fix
8. `deno lint` — 4 files; `tests/setup.ts` needs `// @ts-ignore: …` + `deno-lint-ignore no-window/require-await`, `tests/tauri-mock.test.ts` needs `no-window` for window.__TAURI_INTERNALS__

Hints: Tauri docs https://v2.tauri.app/develop/tests/ + /develop/tests/mocking/ (mockIPC/mockWindows/shouldMockEvents, randomFillSync crypto polyfill).
Absolute manifest path required in worktrees: `/mnt/2tb-storage/stremio-accru-progtests/src-tauri/Cargo.toml`.
