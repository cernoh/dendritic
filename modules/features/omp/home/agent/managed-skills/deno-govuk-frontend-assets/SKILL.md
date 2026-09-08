---
name: deno-govuk-frontend-assets
description: "Serve GOV.UK Frontend (govuk-frontend npm package) assets from a Deno server and keep Nix flake checks offline. Use when building a Deno website styled with alphagov/govuk-frontend, serving govuk CSS/JS/fonts locally, or running deno tests inside nix flake check sandboxes."
---

# Deno + GOV.UK Frontend + offline Nix checks

Facts learned building FPL Wrapped (Deno 2.9, govuk-frontend 6.5.0, NixOS).

## Serving govuk assets from Deno — do NOT import the npm package

- `import.meta.resolve("npm:pkg@ver")` returns the literal `npm:` specifier
  URL, NOT a file path — you cannot derive the package directory from it.
  Do not build asset resolution on `import.meta.resolve`.
- govuk-frontend dist layout: CSS at `dist/govuk/govuk-frontend.min.css`,
  JS `dist/govuk/govuk-frontend.min.js`, fonts/images under
  `dist/govuk/assets/...` (v6 moved assets under the `govuk/` dir). Keep URL
  paths mirroring that structure so relative CSS font references work.
- Reliable pattern: mirror files on demand from unpkg into a cache dir
  (`$XDG_CACHE_HOME/app/govuk-<version>`), single-flight per file
  (`Map<string, Promise>` lock; write temp file then rename for atomicity).
  Env override `FPL_GOVUK_DIR` (unpacked dist/govuk dir) for offline runs.
  Warm the core assets (css, js, fonts, crest, favicon) at server boot with
  `void warm()` so the first page load isn't slow.
- Content types: `.woff2` → `font/woff2`, `.svg` → `image/svg+xml`,
  `.css`/`.js` as usual. Guard `..`/NUL in requested paths.
- Unofficial services styled like GOV.UK: skip the crown crest in the
  header (Crown copyright — only official services may use it) and say
  "not affiliated" in the phase banner/footer.

## GOV.UK page markup notes

- `<caption>` must be the bare first child of `<table>` — never wrap it in
  a `<div>` (invalid HTML). Use `govuk-table__caption govuk-table__caption--m`.
- Headers without a logo: put the service name in
  `govuk-header__content` directly.
- Bespoke styles: prefix everything `fpl-`-style (repo/app prefix) so no
  collision with govuk classes; keep GOV.UK palette (#1d70b8 blue,
  #d4351c red, #0b0c0c text, #b1b4b6 borders, #00703c success green).

## Keeping `nix flake check` offline (deno gates)

- `stdenv.mkDerivation` check derivations run with NO network:
  - Unit tests must not import `jsr:`/`npm:`/remote URLs (first fetch needs
    network). Write a small local `testutil.ts` (assertEquals/assertThrows/
    assertStringMatch etc., ~60 lines, deep-equal incl. arrays/objects) and
    import that instead.
  - `deno fmt` has NO `--exclude` CLI flag ("unexpected argument" error).
    Exclusions go in `deno.json` `"fmt": {"exclude": [...]}` — plain
    `deno fmt --check` then honours them.
  - `deno fmt` also formats Markdown/JSON — exclude captured fixture dirs,
    and run it once over new AGENTS.md/README so later `--check` passes.
- check-derivation template:
  `buildInputs = [ pkgs.deno ]`, `buildPhase = "deno fmt --check && deno check src && deno test -A src"`, `installPhase = "mkdir -p $out"`, `src = self`.
- Markdown test comments are fine; what matters is that no module in the
  test graph performs a remote import.

## Quick reference

- Money fields from the FPL API are £0.1m integers (bank 15 = £1.5m) —
  divide by 10 at presentation, once, in one place.
- Deno: `deno test -A src` type-checks as it runs; `deno check src` for
  static gates. Tests importing only local modules run offline.
