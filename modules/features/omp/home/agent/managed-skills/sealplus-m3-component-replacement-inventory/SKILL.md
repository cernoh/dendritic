---
name: sealplus-m3-component-replacement-inventory
description: "Ground a Material 3 component/glyph replacement inventory for the Sealplus redesign (map #19) against the pinned BOM: download the material3 sources jar and AAR, run the javap opt-in pass, and survey the hand-rolled component's behaviours and call sites before writing the decision round."
---

Use when a task on `cernoh/Sealplus` (map #19 or its remaining tickets #23, #15, #16, #17, #18) must decide or verify which Material component replaces a hand-rolled one, or which Material Symbols glyph replaces an icon. Route issue prose through `issue-scribe`; this skill only measures.

## 1. Material-side facts: measure, never recall

Compose BOM `2026.05.01` resolves `material3` to **1.4.0**. Get the truth from the artifacts, not from docs:

```bash
cd /tmp/<slug>
curl -sfS -o m3-sources.jar https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.4.0/material3-android-1.4.0-sources.jar
curl -sfS -o m3.aar        https://dl.google.com/dl/android/maven2/androidx/compose/material3/material3-android/1.4.0/material3-android-1.4.0.aar
unzip -o -q m3.aar classes.jar -d m3 && mkdir -p m3src && unzip -o -q m3-sources.jar -d m3src
# adaptive navigation suite: same recipe with artifact material3-adaptive-navigation-suite-android
```

The sources jar is the readable authority (`commonMain/androidx/compose/material3/*.kt`, plus `androidMain/*.android.kt`).
For a declaration's annotations, use the **`read` tool with a line range** — an `awk` ring buffer around the match line works from bash when you need several at once:

```bash
awk '{b[NR%8]=$0} /fun (SearchBar|ListItem|AlertDialog|ModalBottomSheet|CircularProgressIndicator)\(/ {printf "%d: ", NR; for(i=1;i<=7;i++) printf "%s | ", b[(NR-7+i)%8]; print ""}' File.kt
```

Opt-in markers are authoritative only in the compiled jar (javap; `nix shell nixpkgs#jdk21`):

```bash
nix shell nixpkgs#jdk21 -c bash -c '
for c in ProgressIndicatorKt ListItemKt AlertDialogKt SearchBarKt ModalBottomSheetKt CardKt SegmentedButtonKt; do
  echo "== $c"
  javap -v -p -cp m3/classes.jar androidx.compose.material3.$c 2>/dev/null | awk "
    /^  (public|protected|private).*\(/ {cur=\$0; sub(/^ +/,\"\",cur); sub(/\(.*/,\"\",cur)}
    /^ +androidx\.compose\.material3\.Experimental/ {print cur\"  <-- \"\$1}
    /^ +kotlin\.Deprecated/ {print cur\"  <-- Deprecated\"}
  " | sort -u
done'
```

### Facts already measured at 1.4.0 (2026-09-20)

- **Absent** (only `tokens/*` classes remain): `ButtonGroup`, `SplitButton`, `FloatingActionButtonMenu`, `LoadingIndicator`, `HorizontalFloatingToolbar`, `ToggleButton`, `MaterialShapes`. They live only on 1.5.0-alpha; ticket #23 decides that line.
- **Present, `@ExperimentalMaterial3Api` required**: `SearchBar`, `DockedSearchBar`, and the newer `TopSearchBar` / `ExpandedFullScreenSearchBar` / `rememberSearchBarState`; `ModalBottomSheet` + `rememberModalBottomSheetState`; `BasicAlertDialog` and the content-slot `AlertDialog`. The app already opts in in 58 files, so opt-in is not a blocker by itself.
- **Present, stable, no marker**: `ListItem` (+ `ListItemDefaults`), `Card`, `AlertDialog(confirmButton = …)`, `CircularProgressIndicator` / `LinearProgressIndicator` **including the track + `gapSize` overloads**, `SegmentedButton` + `SingleChoiceSegmentedButtonRow` / `MultiChoiceSegmentedButtonRow`, `NavigationSuiteScaffold` (the state-taking overloads; the older ones are deprecated).
- `ModalBottomSheet` takes `sheetGesturesEnabled`, a nullable `dragHandle`, `shape` and `contentWindowInsets` (default `BottomSheetDefaults.windowInsets`) — the M2 `NavigationBarSpacer` hack is replaced by insets, not ported.

## 2. App side: behaviour inventory before any recommendation

For each hand-rolled component, get (a) declarations with line numbers, (b) the behaviours a stock Material component does **not** give, (c) every call site as `file:line` split **production vs `@Preview`-only**. The split is decisive: several "load-bearing" components collapsed to one real consumer.

Measured 2026-09-20 (re-verify before reuse):

- `SelectionGroup.kt` (205) — one production consumer, `DownloadPageV2.kt:431-439`; spring corner 16↔20 dp at `:92-99`.
- `ActionSheet.kt` (556) + `ActionSheetItems.kt` (139) — **not FAB-launched**: the FAB at `DownloadPageV2.kt:633` calls `downloadCallback`, the sheet opens at `:522`/`:542` via `showActionSheet` (`:381`). `DownloadLogButton` is dead.
- `GradientProgressIndicator.kt` (93) — 3 production sites.
- `SearchBar.kt` (94) — 2 production sites; a list filter, not a search experience.
- `ModalBottomSheetM2.kt` (184) vs `ModalBottomSheetM3.kt` (59) — the M2/M3 split exists only for `Build.VERSION.SDK_INT < 30` at `DownloadSettingsDialog.kt:487`; the wrappers carry no SDK fork.
- `Dialogs.kt` (336) — `SealDialog` 39 production sites / 23 files, already `BasicAlertDialog` + a hand-built Surface; `SealDialogVariant`, `SealDialogButtonVariant` and the three corner shapes have **zero** production sites (only the preview-only `MeteredNetworkDialog.kt`).
- `PreferenceItems.kt` (856) — 16 composables, 154 production call sites; `PreferenceSwitch` 34, `PreferenceItem` 37, `PreferenceSubtitle` 33, `PreferenceSingleChoiceItem` 14. `PreferencesCautionCard` is dead. `SettingItem.kt` (191) is **entirely dead**: zero call sites, one commented trace at `GeneralDownloadPreferences.kt:179`.
- `ui/svg/drawablevectors/` (3,015) — multi-colour scene art, three live call sites; no glyph can replace it.
- Non-Compose icon paths that cannot become vectors: `NotificationUtil.kt` small/action icons, launcher and splash art, seven brand marks (`SponsorsPage.kt:358-362`, `SupportDeveloperPage.kt:256-319`).

## 3. Icons

The pipeline, mapping rule, alias table, fill-variant plans and the 226-row call-site table are settled in ticket #10 — read `research/material-symbols-vectors.md` and `research/ticket10-glyph-mapping.tsv` on branch `research/material-symbols-vectors`; do not re-measure. Use the `github` tool `file_read`, or `git show origin/<branch>:<path> > /tmp/...` then the `read` tool.

## Traps

- The bash tool blocks shell `grep`/`cat`/`head`/`find`: use the `grep`/`read`/`glob` tools, keep bash for one-call counts (`git grep -o -F 'X(' -- <path> | wc -l`).
- `git grep -c` returns `file:count`; sort with `sort -t: -k2 -rn` to rank the busiest files.
- A file can define a private shadow of a shared component (`InputUrlDialog.kt:405`, `GeneralDownloadPreferences.kt:440`, `YtdlpUpdateDialog.kt:58` each shadow `DialogSingleChoiceItem*`) — a raw grep over-counts those call sites.
- The `javap` annotation pass needs the AAR's `classes.jar`; the sources jar alone does not show which overloads carry the marker.
- Verify a subagent's call-site counts yourself before they enter a decision record: the headline numbers held, and the raw counts were 39/34/33 for `PreferenceItem`/`PreferenceSwitch`/`PreferenceSubtitle`.
