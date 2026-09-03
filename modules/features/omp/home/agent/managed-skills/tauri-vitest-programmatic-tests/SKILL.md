---
name: tauri-vitest-programmatic-tests
description: Programmatic test harness for Tauri v2 + SvelteKit (Rust unit + Vitest mocks) with worktree absolute-path and Deno lint gates
---

# Tauri Vitest Programmatic Tests

Use when adding programmatic tests to a Tauri v2 + SvelteKit repo (stremio-accru pattern).

## Stack
- Rust: `cargo test` unit tests in `src-tauri/src/**/{mod}.rs` via `#[cfg(test)] mod tests`
- Frontend: Vitest + jsdom + `@tauri-apps/api/mocks` (mockIPC/mockWindows/shouldMockEvents) per https://v2.tauri.app/develop/tests/mocking/
- Setup: `vite.config.ts` from `vitest/config` with `test: { environment: "jsdom", globals: true, setupFiles: ["./tests/setup.ts"] }`
- Polyfill: `tests/setup.ts` needs `randomFillSync` crypto for mockIPC: `Object.defineProperty(window, "crypto", { getRandomValues: ... })` and fetch guard.
- Verify: `scripts/verify.sh` 8 gates mirroring CI: cargo check, cargo test (44), svelte-kit sync, vite build, svelte-check, vitest (27), deno fmt --check, deno lint

## Worktree Gotcha (critical)
`write xd://edit` with relative `[src-tauri/...#TAG]` resolves against cwd checkout, not worktree → edits silently lost (cargo test shows 0). Always use absolute worktree paths: `/mnt/.../stremio-accru-progtests/src-tauri/src/...` and confirm `cargo test --manifest-path /abs/src-tauri/Cargo.toml` shows non-zero count.

## Rust Template
Add per-module `#[cfg(test)]` covering behavior boundaries (e.g. `player/skip::detect_intro` 90s boundaries, `tracks::select_best` per-kind lang via `wanted_lang = match kind { "audio"=>audio_lang, "subs"=>subs_lang }`).

## Frontend Template
- `src/lib/features/hero/modules/config.test.ts` / `cache.test.ts` / `catalog-service.test.ts` with localStorage + fetch mocks via `vi.stubGlobal`
- `tests/tauri-mock.test.ts`: mockIPC add/spy via `vi.spyOn(window.__TAURI_INTERNALS__, "invoke")`, dispatch_action/get_state/load, error, mockWindows, shouldMockEvents emit/listen. Fix svelte-check: `// @ts-ignore: Tauri internals mocked by mockIPC`

## Deno Gates
`deno.json` lint excludes `src/` → `tests/` is linted. `// @ts-ignore` needs `: description` (ban-ts-comment), add `// deno-lint-ignore no-window/require-await -- reason` for jsdom/fetch. Remove unused ignores (ban-unused-ignore). Run `cargo fmt; deno fmt; deno lint` must pass before push; `deno fmt` wraps markdown 80-col (README/PLAN).

## Verification
```
nix develop -c cargo test --manifest-path /abs/src-tauri/Cargo.toml  # 44
nix develop -c bash -c 'cd /abs && npx vitest run'                      # 27
nix develop -c bash scripts/verify.sh                                   # 8/8
```
