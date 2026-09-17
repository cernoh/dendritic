---
name: terminal-font-feature-verification
description: "Prove a terminal font change end to end (ghostty): real family string, GSUB feature target glyph, glyph-shape rendering for alternate zeros and cursive italics, ghostty flag validation routes, face-resolution log, and the proof-window and vision-crop traps. Use when asked to change a terminal font, enable slashed zero/ligatures, or get cursive italics."
---

# Verifying a terminal font change (ghostty)

Verified against `cernoh/dendritic` ghostty wrapper: `pkgs.cascadia-code` 2407.24, family `Cascadia Code NF` (2026-09, issue #218); earlier against `pkgs.nerd-fonts.caskaydia-cove` 3.5.0.

## 1. Family string comes from the font, not the package or filename

```bash
nix shell nixpkgs#fontconfig -c fc-scan --format '%{family}|%{style}\n' <file>.ttf
```
Two packages hold Cascadia Code in nixpkgs, and their family strings differ:

- `pkgs.cascadia-code` — Microsoft's own release. It ships `CascadiaCode*`, `CascadiaCodePL*`, `CascadiaCodeNF*` and the Mono sets. The NF statics carry family **`Cascadia Code NF`**, styles `Regular` / `Italic` / `Bold Italic`. The string "Nerd Font" is not in it.
- `pkgs.nerd-fonts.caskaydia-cove` — the Nerd Fonts patch of the same design. Nerd Fonts ships **three families per typeface**: `CaskaydiaCove Nerd Font` (ligatures, double-width icons), `CaskaydiaCove Nerd Font Mono`, `CaskaydiaCove Nerd Font Propo`. Style string is plain `Italic` / `Bold Italic`.

`fc-scan` decides which string to write into the config. A package name never does.

## 2. A feature tag is only real if GSUB maps it

Ghostty **silently ignores unknown `font-feature` values**, so a guessed tag is a no-op. Prove it from the font:

```bash
nix shell nixpkgs#python3Packages.fonttools -c ttx -q -t GSUB -o /tmp/gsub.ttx <file>.ttf
# FeatureTag value="zero"  ->  <LookupListIndex index=".." value="299"/>
# then read <Lookup index="299"> : <SingleSubst in="zero" out="zero.zero"/>
```
Feature enable syntax is the bare tag (`font-feature = zero`, CLI `--font-feature=zero`); `-calt` disables.

`ss01` is the cursive italic of Cascadia Code. It exists in the **Italic face only** — the Regular, Bold, and PL/NFF variants carry `calt`, `ss02`, `ss19`, `ss20` and `zero`, but no `ss01` at all. A global ghostty `font-feature=ss01` is therefore a no-op on upright text, which is what makes it safe to set beside `font-family`. In that face it maps `f`, `l`, `l*`, `r`, `s`, `s*` to their `.salt` cursive alternates.

## 3. Prove the alternate glyph's shape from outlines

Naming is not shape: `zero.zero` must be shown to be the *slashed* one, and `f.salt` the cursive one. Dump outlines:

```bash
ttx -q -t glyf -o /tmp/glyf.ttx <file>.ttf          # 30 MB XML, parse in JS/Bun
```
Parse `<TTGlyph name="zero">` / `name="zero.zero"` contours (`<pt x y on>`), emit an SVG path
(on-curve pairs -> `L`; off-curve -> `Q` with implied midpoints for consecutive off-curve points; flip Y),
then rasterize the SVG and read the image. `read` renders a local `.svg` directly with the `:img` selector, so no ImageMagick is needed.

**The contour bounding boxes answer it without pixels.** Result for Cascadia Code NF (Regular):

- `zero` — three contours: the outer oval, the inner counter, and a separate small closed shape at x 450..750, y 550..850. That is the dot.
- `zero.zero` — three contours: the outer oval and the inner counter **split in two** by the diagonal (x 330..825, y 478..1256 and x 386..870, y 164..904). That is the slash.

So **default `zero` is dotted; `zero.zero` is slashed** — `zero` is exactly the flag that satisfies "slashed zero", and without it the terminal shows a dot. `f.salt` carries the descender loop that `f` lacks.

**Do not** rewrite the font's `cmap` to force the alternate glyph (a full ttx round-trip of a 40 MB XML
risks the hinting tables, and the remap must hit all four `0x30` rows or some shapers still pick the default).

## 4. Ghostty flag validation routes

- `ghostty --<key>=<v> +show-config` prints **nothing**: config flags before an action mute it. This is
  documented wrapper behaviour, **not** a parse failure. Do not read it as a verdict either way.
- `ghostty +validate-config --config-file=/tmp/x.conf` with the keys in a file: exit 0 and no output = keys and
  values parse. Valid keys include `font-family`, `font-family-italic`, `font-style`, `font-style-italic`,
  `font-feature`, `font-synthetic-style`, `font-size`.
- `ghostty +list-fonts --family=<family> [--style=Italic]` uses ghostty's real discovery path. Fonts not yet in
  the system profile need `FONTCONFIG_FILE` pointed at a config whose `<dir>` is the store font path. `--style=Italic`
  prioritising the italic face first is the evidence that the style string matches the real face.
- Repeated `--font-feature=` flags parse: one run with `ss01` and `zero` logs no config error and resolves both.
- **Best proof of face resolution**, from ghostty's own stderr at run time:
  `info(font_shared_grid_set): font regular: Cascadia Code NF Regular`,
  `font bold: Cascadia Code NF Bold`, `font italic: Cascadia Code NF Italic`,
  `font bold_italic: Cascadia Code NF Bold Italic`.
  That closes "family + italic face selected" without any pixels.

## 5. Italic is an application-side request

The terminal only chooses a face. Cursive comments appear only if the editor emits SGR 3 (`\e[3m`).

In this flake the editor does: nvf sets the theme to `base16`, which RRethy's `base16-colorscheme` paints with
`TSComment = { gui = 'italic' }`, and `features/nvf/_languages.nix` sets `enableTreesitter = true`, so the comment
groups reach the terminal as italic. The `luaConfigPost` transparency pass clears only `bg`, so it keeps the
attribute.

## 6. Rendering proof — get consent, and never touch the operator's windows

Launching ghostty on the operator's live Wayland session **opens a window on their desktop**. Ask first. Then:

- Launch and capture inside ONE tool call. A backgrounded GUI process dies when the call returns, so a later call captures an empty desktop.
- Kill by the exact PID captured from `$!`. A `pgrep -f` pattern such as `bin/ghostty --font-family` also matches the operator's own terminal, and `kill` then closes their session.
- Capture the whole layout with bare `grim`, then crop with ffmpeg:
  `ffmpeg -y -vf "crop=W:H:X:Y,scale=iw*5:ih*5:flags=neighbor" full.png crop.png`.
- A tiling compositor reports client geometry in a group space that does not match `grim`'s layout space: `mmsg get all-clients` gave `x=1920` for a window that was drawn on the left monitor, so `grim -g` captured a browser. `mmsg` also needs `MANGO_INSTANCE_SIGNATURE` (`/run/user/1000/mango-<pid>.sock`, readable from `/proc/<pid>/environ` of any mango-spawned process).
- Bootstrapping without a display: `FONTCONFIG_FILE` with only the store font dir is enough for `+list-fonts`, and `WAYLAND_DISPLAY` plus `XDG_RUNTIME_DIR` are enough for a render.

Traps, all hit in practice:
- Vision models **miss a dot or slash at 16 pt** and report "plain zero" for a dotted glyph. Always crop tight and scale ~250% before asking.
- **Never name the expected strings in the vision prompt.** A transcription that merely echoes your prompt is
  worthless; ask "transcribe and say whether each zero is slashed, dotted, or plain" with no sample text given.
- A vision pass at 1:1 on a two-monitor layout (3840 px shown at 1568 px) called the cursive italic "plain, merely slanted", with no loops. A 5x nearest-neighbour crop of the same pixels showed the loops plainly. Low zoom loses cursive, so crop before you ask.
- A whole-output `grim` diff is noisy on a live desktop (the operator's own terminal repaints). Prefer
  before/after diff for the bbox, or accept a half-screen crop and confirm by unique sample text.
- Weston headless + `weston-screenshooter` captured blank frames here; do not iterate on it beyond one try.
