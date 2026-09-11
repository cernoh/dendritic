---
name: noctalia-toml-to-nix-settings
description: "Translate a Noctalia config.toml export into a Nix programs.noctalia.settings data file without type drift: float-vs-int literal handling, the dropped out-of-store plugin, the json2x one-ULP rounding, and the proof recipe (config-validate build, deep TOML diff, baseline-store-path comparison). Use when moving a live Noctalia shell into dendritic or when a rebuild would otherwise overwrite the tuned shell."
---

# Noctalia TOML export → Nix settings

Apply when a host's live `~/.config/noctalia/config.toml` must become
`programs.noctalia.settings` (dendritic: `modules/hosts/<HOST>/_noctalia-settings.nix`,
imported as `programs.noctalia.settings = import ./_noctalia-settings.nix;`).

The noctalia HM module types `settings` as `oneOf [ tomlFormat.type str path ]`
and renders it through `pkgs.formats.toml`. Nixpkgs' TOML type **rejects plain
integers**, so every numeric literal must keep the type the export gave it.

## Translate

Parse with `Bun.TOML.parse` (no python on NixOS). Do not hand-copy: 700+ lines.

Render, then keep the literal text of floats:

1. Scan the raw text with a small header parser that tracks `[table]` and
   `[[array-of-table]]` (indexed, so occurrences map to array elements).
2. Record each key path whose literal matches a float pattern.
3. Emit `litText.get(path)` for those paths and `String(v)` for the rest.
   Integers render bare — writing an int where the export had a float fails eval.

Array-of-table paths need `.*` in the key so `capsule_group[].opacity` and
`shell.session.actions[].countdown_seconds` stay floats.

Deviation to apply by hand: the shell export lists only plugins that come from
a plugin source. A plugin delivered by out-of-store symlink (dendritic
`cernoh/terminal`) is absent, yet the bar uses its widget — add the name back to
`plugins.enabled` and comment why.

Quote non-identifier keys: `"lockscreen-login-box@DP-1"` must render as
`"lockscreen-login-box@DP-1" = { … }`. Escape `\`, `"`, `\${` in strings.

## Prove

```bash
nix-instantiate --parse modules/hosts/<HOST>/_noctalia-settings.nix
<nixfmt-rfc-style>/bin/nixfmt modules/hosts/<HOST>/_noctalia-settings.nix   # then --check
git add …                                   # untracked files are invisible to flake source copies
nix build --impure --no-link --print-out-paths \
  .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.xdg.configFile."noctalia/config.toml".source
```

That build runs `noctalia config validate` (default `checkConfig = true`), so a
green build proves the schema, not just the syntax.

Deep-diff generated vs source with a recursive key walk. Expect exactly two
kinds of noise:

- Absent plugin names (intentional, above).
- One-ULP rounding on some opacities: `0.97000002861022949` in the export
  becomes `0.9700000286102296` because nixpkgs' `json2x` writer round-trips
  through `builtins.toJSON`. Bit-compare with `DataView.setFloat64` before
  calling it a real difference. Cosmetic for an opacity.

Counts that should match on both sides: float literals, integer literals, leaf
key paths. `nixpkgs` `json2x --unwrap` sorts keys, so key order is not evidence.

Prove other hosts are untouched by comparing store paths, not by reading diffs:
`git worktree add --detach .worktrees/baseline origin/main`, eval the same
`xdg.configFile."noctalia/config.toml".source` there, compare to your branch.
Identical path = untouched.

## Gotchas

- Float-only `tomlFormat` means `font_weight = 500` stays an int while
  `capsule_padding = 6.0` stays a float. Both are in the same bar table.
- `wallpaper.directory` may be absolute in the export where the Nix form used
  `~`. Keep the export value and say so in the file header.
- `import-tree` skips `/_`; the `_` prefix is what keeps this data file out of
  auto-registration, and the owning host config must import it explicitly.
