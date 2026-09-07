---
name: nix-dotnet-linux-ocr-setup
description: "Set up a Nix dev shell so .NET code using System.Drawing + Tesseract.NET (charlesw/tesseract) builds and runs natively on Linux. Trigger when a net9/net8 project fails with PlatformNotSupportedException for System.Drawing, tesseract DllNotFound/native load errors on Linux/NixOS, or when writing a Nix flake devShell for .NET OCR code (incl. WFinfo-ext headless workflow)."
---

# .NET OCR on Linux/NixOS — dev shell + native deps

Hard-won recipe (empirically verified on NixOS 2026-09, .NET 9.0.317, tesseract 5.5.3 via nixpkgs, in the WFinfo-ext repo).

## 1. System.Drawing.Common version matrix on Linux (verified)

| Version | On net9.0 runtime, Linux | Why |
|---|---|---|
| 9.x | `PlatformNotSupportedException` | Unix/libgdiplus path removed; `EnableUnixSupport` switch ignored |
| 8.0.x (all) | `PlatformNotSupportedException` | Same gate — PNSE even with `EnableUnixSupport: true` in runtimeconfig |
| 7.x | `PlatformNotSupportedException` ("not supported on this platform") | Unix support removed in 7 |
| **6.0.0** | **Works** (Bitmap + Graphics OK) | Last line whose loader honors `EnableUnixSupport` and dlopens plain `libgdiplus.so` |

**Pin `System.Drawing.Common` 6.0.0** in net9.0 projects (net6 asset loads fine). Keep
the runtimeconfig switch (6.x needs it):

```xml
<PackageReference Include="System.Drawing.Common" Version="6.0.0" />
...
<RuntimeHostConfigurationOption Include="System.Drawing.EnableUnixSupport" Value="true" />
```

The 9.x loader probes Windows-style names (`gdiplus.dll.so`, `libgdiplus.dll`, ...);
6.x uses plain `libgdiplus.so` via `LD_LIBRARY_PATH`.

## 2. Tesseract.NET (charlesw/tesseract 5.2.0) natives

- NuGet ships **Windows-only** natives (x64/x86 .dll). No linux .so in the package.
- The wrapper (InteropDotNet) dlopens **exact sonames**:
  `libtesseract50.so` and `libleptonica-1.82.0.so` (base names only; it appends
  platform prefixes/suffixes itself).
- nixpkgs `tesseract5`/`leptonica` ship versioned libs
  (`libtesseract.so.5...`, `libleptonica.so.6...`), so build a symlink farm:

```nix
farm = pkgs: pkgs.runCommand "native-libs" { } ''
  mkdir -p $out/lib/x64 $out/lib/x86
  tess=$(find ${pkgs.tesseract5}/lib -maxdepth 1 -name 'libtesseract.so.*' | sort | tail -n1)
  lept=$(find ${pkgs.leptonica}/lib -maxdepth 1 -name 'libleptonica.so.*' | sort | tail -n1)
  ln -s "$tess" $out/lib/libtesseract50.so
  ln -s "$lept" $out/lib/libleptonica-1.82.0.so
  # x64/, x86/ copies too — the loader may search platform subdirs
'';
```

- Point the wrapper at it before creating engines:
  `TesseractEnviornment.CustomSearchPath = "/nix/store/...-native-libs/lib";`
- Managed TesseractEngine (netstandard2.0) has **no Bitmap overload** (no
  System.Drawing dep); the net48 build does. On net9 use a lossless PNG
  round-trip: `bitmap.Save(ms, ImageFormat.Png)` →
  `Pix.LoadFromMemory(ms.ToArray())` → `engine.Process(pix, pageSegMode)`.
- tessdata: if missing, engines throw `TesseractException`. WFinfo fetches
  locale traineddata from `raw.githubusercontent.com/WFCD/WFinfo/libs/tessdata`
  with MD5 checksums; locales ja/th/tr are not downloadable.
- `tesseract 5.5.3` natives worked with the 5.2.0 wrapper (stable BaseAPI).
  Dispose engines before exit or libtesseract prints `ObjectCache LEAK` warnings.

## 3. Nix flake idiom (avoids "cannot coerce a set to a string")

Passing an imported pkgs set where consumers expect the system string breaks
evaluation. Use ONE idiom consistently:

```nix
# Idiom (b) — consumers receive pkgs and MUST NOT re-import nixpkgs:
forAllSystems = f:
  nixpkgs.lib.genAttrs systems (system: f (nixpkgs.legacyPackages.${system}));
# consumer:
packages = forAllSystems (pkgs: { my-drv = ... pkgs ...; });
```

Never `import nixpkgs { inherit system; }` inside a consumer whose `system` param
is actually the pkgs set — nixpkgs then tries to elaborate `system = <pkgs>` and
fails with a coerce error deep in `lib/systems`.

## 4. NixOS dev shell wiring for .NET

```nix
pkgs.mkShell {
  packages = with pkgs; [ dotnet-sdk_9 libgdiplus fontconfig dejavu_fonts ];
  env = {
    LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.libgdiplus pkgs.openssl pkgs.icu pkgs.zlib pkgs.fontconfig ];
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
    # + WFINFO_NATIVE_LIBS-style var pointing at the tesseract farm
  };
}
```

- dotnet runtime dlopens openssl/icu at runtime → LD_LIBRARY_PATH.
- libgdiplus text rendering needs fontconfig + fonts → FONTCONFIG_FILE via
  `pkgs.makeFontsConf`; render text with an installed family (DejaVu Sans).

## 5. WFinfo-ext concrete workflow (this repo)

Shared sources live in `WFInfo/`; the Linux runner links them from `headless/`
(no copies; compile-time seams in `headless/Platform/` for WPF/WinForms/Win32
type references). Verify natively:

```bash
nix develop -c dotnet build headless/WFInfo.Headless.csproj   # clean build
nix develop -c dotnet run --project headless -- --selfcheck   # OCR proof (expect PASS)
nix develop -c dotnet run --project headless -- --test tests/map.json out.json
nix develop -c dotnet run --project headless -- --theme-test <folder>
```

Exit codes: 0 pass / 1 partial / 2 fatal. Capture with `; echo $?` — `$?` after a
pipe measures the last command, not dotnet. `tests/data/` lacks PNG fixtures, so
suite scenarios error "PNG not found" (pre-existing repo state).

Environment vars honored by the headless runner: `WFINFO_NATIVE_LIBS` (native
lib dir), `WFINFO_DATA_DIR` (app-data root; tessdata + market DBs land under
`<data>/WFInfo` via XDG_CONFIG_HOME mapping).

## Notes

- WPF/.NET Framework 4.8 GUI remains Windows-only; shared-file edits must be
  Windows-equivalent (e.g. `Path.Combine`, never `+ @"\..."`).
- Do not fork shared core code into the runner — link it; platform seams throw
  `NotSupportedException` rather than faking behavior.
