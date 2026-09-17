---
name: terminal-font-feature-verification
description: "Prove a terminal font change end to end (ghostty/Nerd Fonts): real family string, GSUB feature target glyph, glyph-shape rendering for alternate zeros, ghostty flag validation routes, face-resolution log, and the vision-crop traps. Use when asked to change a terminal font, enable slashed zero/ligatures, or get cursive italics."
---

# Verifying a terminal font change (ghostty + Nerd Fonts)

Verified against `cernoh/dendritic` ghostty wrapper + `pkgs.nerd-fonts.caskaydia-cove` 3.5.0, 2026-09.

## 1. Family string comes from the font, not the package or filename

```bash
nix shell nixpkgs#fontconfig -c fc-scan --format '%{family}|%{style}\n' <file>.ttf
```
Nerd Fonts ships **three families per typeface** and they are not interchangeable in config:
`CaskaydiaCove Nerd Font` (ligatures, double-width icons), `CaskaydiaCove Nerd Font Mono` (single-width), `CaskaydiaCove Nerd Font Propo`. Style string is plain `Italic` / `Bold Italic`.

## 2. A feature tag is only real if GSUB maps it

Ghostty **silently ignores unknown `font-feature` values**, so a guessed tag is a no-op. Prove it from the font:

```bash
nix shell nixpkgs#python3Packages.fonttools -c ttx -q -t GSUB -o /tmp/gsub.ttx <file>.ttf
# FeatureTag value="zero"  ->  <LookupListIndex index=".." value="299"/>
# then read <Lookup index="299"> : <SingleSubst in="zero" out="zero.zero"/>
```
Feature enable syntax is the bare tag (`font-feature = zero`, CLI `--font-feature=zero`); `-calt` disables.

## 3. Prove the alternate glyph's shape without a browser (browser here often times out)

Naming is not shape: `zero.zero` must be shown to be the *slashed* one. Dump outlines and rasterize:

```bash
ttx -q -t glyf -o /tmp/glyf.ttx <file>.ttf          # 30 MB XML, parse in JS/Bun
```
Parse `<TTGlyph name="zero">` / `name="zero.zero"` contours (`<pt x y on>`), emit an SVG path
(on-curve pairs -> `L`; off-curve -> `Q` with implied midpoints for consecutive off-curve points; flip Y),
then `magick x.svg x.png` and read the PNG.

Result for Caskaydia Cove: **default `zero` is dotted; `zero.zero` is slashed** — so `zero` is exactly the
flag that satisfies "slashed zero", and without it the terminal shows a dot.

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
  prioritising `... NF Italic` first is the evidence that the style string matches the real face.
- **Best proof of face resolution**, from ghostty's own stderr at run time:
  `info(font_shared_grid_set): font regular: CaskaydiaCove NF Regular` / `font italic: CaskaydiaCove NF Italic`.
  That closes "family + italic face selected" without any pixels.

## 5. Italic is an application-side request

The terminal only chooses a face. Cursive comments appear only if the editor emits SGR 3 (`\e[3m`) — check the
editor theme config too, or the font work changes nothing visible.

## 6. Rendering proof (when you want pixels)

Find the built wrapper by grepping its `bin/ghostty` script for the new family — the store accumulates several
`ghostty-wrapped` derivations.

Traps, all hit in practice:
- Vision models **miss a dot or slash at 16 pt** and report "plain zero" for a dotted glyph. Always crop tight and
  scale ~250% before asking.
- **Never name the expected strings in the vision prompt.** A transcription that merely echoes your prompt is
  worthless; ask "transcribe and say whether each zero is slashed, dotted, or plain" with no sample text given.
- A whole-output `grim` diff is noisy on a live desktop (the operator's own terminal repaints). Prefer
  before/after diff for the bbox, or accept a half-screen crop and confirm by unique sample text.
- Weston headless + `weston-screenshooter` captured blank frames here; do not iterate on it beyond one try.
- Kill stray proof instances by the script path (`pkill -f /tmp/proof.sh`), never by a font flag that could match
  the user's live terminal. Leave no window open.
