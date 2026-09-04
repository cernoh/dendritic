---
name: deno-desktop-nixos
description: Make downloaded Deno Desktop (laufey) backends run on NixOS via patchelf and lib closure
---

# Deno Desktop on NixOS

Run `deno desktop` (laufey backends) on NixOS where /lib64/ld-linux is stub-ld and NIX_LD is empty.

## Symptoms
- `Could not start dynamically linked executable ... NixOS cannot run dynamically linked executables` (exit 127).
- Webview backend: `Gdk Error 71 dispatching to Wayland display` (loader OK, libs/ABI issue).
- CEF backend: window never maps but CDP `/json/list` shows unified + runtime + renderer targets.

## Procedure
1. Identify binaries: bundle output dir + `~/.cache/deno/laufey/<ver>/{webview,cef}/x86_64-unknown-linux-gnu/`.
2. Build lib closure empirically: `ldd <binary> | grep 'not found'`, iterate. Webview (webkit2gtk 4.1 ABI) + CEF (NSS/NSPR/ALSA/CUPS/libXi/udev) set. Note `glib.out` (not `glib`), `cups.lib`, `gcc.cc.lib`.
3. In flake wrapper: `export LD_LIBRARY_PATH=${nixpkgs.lib.makeLibraryPath (libs)}` and add same libs to devShell + shellHook.
4. Bundle (always recompiled): build to `$XDG_CACHE_HOME/<app>/bundle` with rebuild guard on `${./scripts}` hash; after `deno desktop --output`, patchelf every ELF: `--set-interpreter $(cat ${stdenv.cc}/nix-support/dynamic-linker)`, `--set-rpath <libs>`.
5. Cache backends (manual, redo after cache clear/version bump): same patchelf; CEF additionally appends `$ORIGIN` rpath (colocated libcef.so) and needs `libEGL.so.1 -> libEGL.so`, `libGLESv2.so.1 -> libGLESv2.so` symlinks in CEF dir.
6. Verify: `env -u LD_LIBRARY_PATH ldd <bin> | grep -c 'not found'` must be 0 before launching.

## App-side gotchas
- Bundle embeds only entrypoint file: pass sibling paths via env (e.g. STREMIO_LAUNCHER), probe env/cwd/sibling.
- parseArgs must skip: bare `--`, `--runtime <path>` (both argv forms), bare `.so` path.
- `node:os homedir()` needs allow-sys in compiled binary: use `Deno.env.get("HOME")`.
- `Deno.BrowserWindow` only exists in desktop runtime: use denidian cast + feature-detect so `deno check` passes.
- CEF unified DevTools: `deno desktop --hmr --backend cef --inspect=127.0.0.1:9230`; probe `/json/list`; evaluate renderer JS via CDP `Runtime.evaluate`.
- Window never mapping on MangoWM is separate from loader: confirm with `mmsg get all-clients` + screenshot.

## Alternatives
- Host `programs.nix-ld.enable = true` removes this class entirely (needs sudo rebuild).
- Self-healing wrapper: auto-patchelf `~/.cache/deno/laufey/` on version change.
