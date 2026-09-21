---
name: dendritic-cursor-theme-wiring
description: "Add or debug a pointer cursor theme in the dendritic flake (~/.config/dendritic): build the theme from a generated source tree with self.scheme colors, wire the two delivery channels (home.pointerCursor and the compositor env), avoid the stylix.cursor conflict, and verify by build plus host eval."
---

# Adding a cursor theme to the dendritic flake

Measured on `cernoh/dendritic` when adding `retrosmart-cursor` (PR #241,
issue #240), 2026-09-21. Reference implementation:
`modules/features/retrosmart-cursor/`.

## Two facts that decide the shape of the feature

1. **A generated theme needs a derivation, not checked-in binaries.** The
   retrosmart fork builds every theme from `schemes.yaml` (`outline`/`fill`,
   `accent` for win-3d) with ImageMagick + xcursorgen + python3/PyYAML. The
   `posy-cursors` pattern (committed theme dirs + `mkOutOfStoreSymlink`) cannot
   work for it. Write the palette colors into `schemes.yaml` in the
   derivation and run the upstream pipeline.
2. **Installing files activates nothing.** Nothing in `modules/` sets a cursor
   name today (only `XCURSOR_SIZE` in mango's env). A feature must set
   `home.pointerCursor` as well.

## The two delivery channels

| Channel | Reaches | Set by |
|---|---|---|
| `home.pointerCursor = { enable = true; package; name; size; gtk.enable = true; }` | home profile, `~/.icons`, `~/.local/share/icons`, GTK/dconf cursor theme, login-shell `XCURSOR_THEME`/`XCURSOR_SIZE` | the HM feature module |
| compositor env | the greeter-spawned compositor and every process it spawns | mango `settings.env` (NIXPC), niri `config.kdl` `environment { }` (ASAHI) |

A greeter-spawned session never sources home-manager session vars, so the
compositor channel is not optional. Read the theme name from one flake output
(`flake.<feature> = { name; size; }`) in both places, so the two cannot drift.
The niri `config.kdl` is a static out-of-store file: it carries a copy plus a
sync comment, which is the repo's accepted pattern for static files.

`XCURSOR_PATH` is already correct on NIXPC without help. A live session shows
`/home/<user>/.icons`, `~/.local/share/icons`, and
`/etc/profiles/per-user/<user>/share/icons` — the last one is where
`home.packages` puts a `pointerCursor.package`. So the theme resolves from any
of the three; only the *name* has to arrive.

## Do not set `stylix.cursor` and `home.pointerCursor` together

stylix's HM module assigns `home.pointerCursor = { inherit (cfg) name package;
enable = true; size = ...; }` as a **plain** (non-`mkDefault`) value, guarded
by `stylix.cursor != null`. Defining `home.pointerCursor` in a feature and
`stylix.cursor` anywhere is a conflicting definition and fails eval on both
hosts. `stylix.cursor` defaults to null and this repo never sets it, so define
`home.pointerCursor` directly. HM also needs `enable = true` explicitly, else
it warns about the deprecated implicit enable.

## Derivation notes for the retrosmart pipeline

- `src` is the source tree, `flake = false`. The tag archive input works and
  Nix uses the repository root (`source root is source`).
- `postPatch` writes `schemes.yaml` with the single scheme and changes the
  ImageMagick 6 binary name: `sed -i 's/^\( *\)convert /\1magick /' build.sh`
  (nixpkgs ships ImageMagick 7, which installs `magick`).
- `buildPhase` runs the steps of upstream's `all` target, minus Windows, and
  calls `bash build.sh <step>`: the script's `#!/usr/bin/env bash` shebang has
  no `/usr/bin/env` in the sandbox (exit 126).
- `installPhase` copies only
  `build_themes/Linux/<style>/retrosmart-xcursor-<schemeId>` into
  `$out/share/icons/`. The `-shadow` twin that upstream registers is built but
  not installed.
- Colors: for mac-ish, `outline` draws the cursor body and `fill` its interior.
  Every upstream mac-ish scheme maps `outline` to the palette foreground and
  `fill` to its background (catppuccin `#cdd6f4`/`#1e1e2e`, gruvbox
  `#ebdbb2`/`#282828`). For the sepia palette that is `text` `#ece0cd` and
  `base` `#1e1813`. A gold variant is one line: `outline =
  self.scheme.hex.primary`.

## Verification that is actually decisive

```bash
nix build .#<package>                 # 49 cursor binaries + 67 aliases
# exact colors, not a vision guess:
nix shell nixpkgs#imagemagick --command magick \
  <theme>/cursors/thumbnail.png -format %c histogram:info:- | sort -rn | head
#   -> #1E1813FF and #ECE0CDFF only

# both hosts, by their real user names (NIXPC: davr, ASAHI: da)
nix eval --impure --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.pointerCursor.name
nix eval --impure --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.pointerCursor.package.outPath
nix eval --impure --json .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.pointerCursor --apply 'p: { inherit (p) size enable name; }'

# the rendered mango config (its runCommand validated it with `mango -c -p`)
nix build .#nixosConfigurations.NIXPC.config.programs.mango.package --no-link --print-out-paths --impure
# then read the -c <path> out of $out/bin/mango and grep for XCURSOR_THEME

# the static niri config: copy it beside an empty noctalia.kdl, or the real
# missing include masks the result
mkdir -p /tmp/niricheck && cp modules/features/niri/config.kdl /tmp/niricheck/ && : > /tmp/niricheck/noctalia.kdl
nix shell nixpkgs#niri --command niri validate -c /tmp/niricheck/config.kdl   # "config is valid"
```

Traps in that list:

- ASAHI's home-manager user is `da`, not `davr`. A wrong user name fails with
  the useless `error: … does not provide attribute … Did you mean da?`.
- `nix eval --raw` cannot print `size` (int) or `enable` (bool); use `--json`
  with an `--apply` map.
- `niri validate` on the config in place always fails, because
  `include "noctalia.kdl"` points at a runtime-generated file. The exit code is
  identical with and without your edit, so it proves nothing by itself.
- The on-screen pointer changes only after a switch **and** a relogin: the
  compositor reads `XCURSOR_THEME` at startup.
