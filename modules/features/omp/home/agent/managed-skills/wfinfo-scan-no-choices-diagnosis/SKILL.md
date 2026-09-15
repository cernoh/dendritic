---
name: wfinfo-scan-no-choices-diagnosis
description: "Diagnose a WFinfo-ext headless reward-screen scan that reports no choices (empty Choices, \"no reward screen detected\"): read the debug.log branch point, escape the theme-retry loop that masks exceptions, fix pixel-format and nameData faults, and verify with a live EE.log-triggered capture. Use when the scan finds no parts, when all 19 themes report \"Unable to find any parts\", or when a change must be proven against the real screen."
---

# WFInfo headless scan: no reward parts found

Use when `--scan` returns `"Choices": []` / `no choices: no reward screen detected`
even though a reward screen is on the captured output.

## 1. Read the branch point — `~/.config/WFInfo/debug.log`

The printed scan result is nearly useless; the reason is in the log. Find the
last `Test ProcessReward: ExtractPartBoxAutomatically failed:` line and match it:

| Log line | Cause | Fix |
|---|---|---|
| `Index was outside the bounds of the array` | Pixel buffer indexed as 32bpp BGRA while the image is 24bpp `Format24bppRgb` (grim PNG) | Use the bitmap's real pitch (`BytesPerPixel`/`ReadPixel`/`WriteGray` in `Ocr.cs`). Never hardcode 4. |
| `Object reference not set` with `at WFInfo.Data.GetPartName` | The scan's `Data` was built without `nameData`, so the English name lookup throws | Load `name_data.json` (`ScanPaths.NameData`) in `headless/Program.cs` |
| `Unable to find any parts` for **all** 19 themes | The theme filter matched no pixels — probe scaling or wrong theme, not a data problem | See step 2 and step 4 |
| `Filtered Image` / `RANK` lines missing entirely | The failure is before the filter (clone/crop/theme) | Re-read the earlier lines; the crop log is `Fullscreen is {…}, trying to clone:` |

`ExtractPartBoxAutomatically failed` alone does **not** mean the theme is wrong.
Both real faults above appear as "no parts".

## 2. Pin `--theme` to escape the retry loop

`RecognizeParts` retries once per theme and swallows the exception, so a deeper
fault is reported as the generic `Unable to find any parts`. Pin one theme to see
the true error and its stack trace:

```bash
nix develop -c dotnet run --project headless -- --scan --no-notify --file /tmp/reward.png --theme STALKER
```

An `EVEN DISTRIBUTION` near 84% means the filter works and the fault is later
(the `GetPartName` path). A missing `EVEN DISTRIBUTION` means the filter failed.

Note: a fixed `--theme` can make a run *look* fixed by skipping the retries. Never
accept a pinned-theme run as proof — re-run unpinned.

## 3. Pixel format is the most common fault

grim writes a 24bpp PNG (3 bytes/pixel, BGR); GDI captures are 32bpp (BGRA).
Every hand-indexed pixel loop must use the real pitch, and the destination buffer
has its own format. Loops to check in `WFInfo/Ocr.cs`: `ExtractPartBoxAutomatically`
(row filter), `FilterAndSeparatePartsFromPartBox` (box split), `ScaleUpAndFilter`
(SnapIt), and the legacy trapezoid theme scan.

Verify format-agnostically, both ways — a fix that only helps one format is a
format swap, not a fix:

```bash
ffmpeg -v error -y -i reward.png -pix_fmt rgba /tmp/reward32.png   # force 32bpp
# both files must read the same part names
```

## 4. Theme probe and UI scale

The probe averages one pixel column at `(150, 85..93) * ScreenScaling * uiScaling`.
It reports weight `0.00` when it samples black instead of the profile bar.

- Pin the theme with `--theme <NAME>` to check the filter itself.
- Probe colours per theme live in `AllThemes` (`Ocr.cs`). At `FlashDrawScale=0.9`
  the probe lands on `ProbeTop` at `y≈77`, not `y≈85`.
- `ReadUiScaleFromConfig` cannot work on Linux: it builds the path with a
  backslash literal and looks under `LocalApplicationData`, not the Proton prefix.
  Do not rely on it to explain observed scaling; measure instead.

Measure a probe yourself without ImageMagick (not installed on this host):

```bash
ffmpeg -v error -y -i shot.png -f rawvideo -pix_fmt rgb24 /tmp/shot.raw
```

```js
const raw = new Uint8Array(await Bun.file('/tmp/shot.raw').arrayBuffer());
const W = 1920;
const px = (x, y) => { const i = (y*W + x)*3; return [raw[i], raw[i+1], raw[i+2]]; };
// average the candidate probe columns for each scale, compare with AllThemes
```

## 5. Verify against the real screen (required)

`--file` proves the OCR path; only a live capture proves capture + OCR. Show the
reward screenshot on the output being captured, then trigger the scan.

```bash
# Output names and layout offsets first — the primary is usually at 0,0.
wlr-randr
```

- Use `--fs-screen-name=DP-1` (**not** `--fs-screen=1`). The index form silently
  puts the image on the wrong monitor and the scan then captures a desktop.
- `--geometry=WxH+X+Y` must match the output's layout offset.

```bash
mpv --really-quiet --no-osc --no-input-default-bindings --loop=inf \
    --geometry=1920x1080+1920+0 --fs --fs-screen-name=DP-1 /tmp/reward.png &
```

Then verify the EE.log trigger path with no game running:

```bash
dotnet run --project headless -- --scan --watch --once --log /tmp/ee.log \
  --no-notify --output DP-1
# after the watcher prints "Watching", append a line containing "Got rewards"
```

## 6. EE.log watch specifics

- Trigger lines: `Got rewards`, `Pause countdown done` (same as the Windows watcher).
- EE.log is **replaced** per session and a replacement can be *longer* than what
  was read, so `length < position` is not a sufficient truncation test. Keep the
  consumed bytes and re-check they are still at that offset (continuity check).
  Symptom without it: `reward screen detected: : ProjectionRewardChoice.lua: Got rewards`
  — the line starts mid-file.
- Hold back a partial trailing line until its newline arrives, or a line splits
  across polls.
- The game writes the trigger *before* the panel draws, so re-capture until a part
  is recognised; write no record for a screen that could not be read.

## 7. Harness traps that waste whole runs

- **Never write script stdout to the file the watcher tails.** It truncates the
  log and creates a false "no trigger" result. Use separate paths.
- `grep -c "reward screen detected"` also matches `no reward screen detected`.
  Count `"^  reward screen detected:"` instead.
- Do not `git add -A` in this repo: `LOG.txt` (a session log) is untracked and gets
  swept into the commit. Stage explicit paths.
- A feature branch stacked on an unmerged fix must be based on that fix, else the
  fix looks un-fixed. Check with
  `git merge-base --is-ancestor <fix-branch> HEAD`.

## 8. Gates

```bash
nix develop -c dotnet build headless/WFInfo.Headless.csproj
nix develop -c dotnet run --project headless -- --selfcheck
cd dashboard && nix develop -c deno fmt --check && nix develop -c deno check src \
  && nix develop -c deno lint && nix develop -c deno test -A src
nix flake check
```

The OCR suite reports `PNG not found` errors for every scenario while
`tests/data/*.png` is absent — that is the pre-existing repo state, not a
regression.
