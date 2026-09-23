---
name: asahi-build-watch-page
description: "Operate the local ASAHI build watch page (~/.local/share/asahi-watch) on NIXPC: start, restart, verify, read the flavour classification, and the known defects that silently disable the done alarm. Use when asked to watch an ASAHI build, when the page shows the wrong flavour or never reaches DONE, or before trusting expected-target.txt."
---

# The ASAHI build watch page (NIXPC side)

Watching `nh os switch` / `nixos-rebuild switch` on ASAHI (aarch64 Mac) from
NIXPC, where the work is emulated. Built 2026-09-22; complements the repo skills
`deno-m3e-build-status-page` and `asahi-overnight-remote-build` (the latter now
carries the flavour gate).

## Layout

```
~/.local/share/asahi-watch/
  server.ts             Deno server: /, /json, /pane, /m3e.js, /symbols.css
  page.html             the M3E page (state lives in shadow roots)
  probe.sh              remote probe, fed to ASAHI over ssh stdin as `bash -s`
  watch.sh              sentinel|stall watcher, talks to ASAHI directly
  supervise.sh          restart loop (pkill patterns inside the file)
  expected-target.txt   "root <outpath>" and "neutral <outpath>" per revision
  refresh-target.sh     regenerates that file with two evals
  vendor/               @m3e/web@2.8.2 bundle + subset Material Symbols font
```

## Operate

```sh
# start (hub is often dead: use setsid nohup, never `hub start`)
cd ~/.local/share/asahi-watch && setsid nohup ./supervise.sh >/dev/null 2>&1 &

# restart after editing server.ts or page.html — the bodies are read into
# memory at startup, so an edit is invisible until the process restarts
pkill -f 'asahi-watch/server.ts'          # supervise.sh relaunches it in ~5 s

# watch for the end without polling the page
./watch.sh sentinel 60     # exits when the client is gone (needs a live sighting first)
./watch.sh stall 60        # exits after 15 probes with zero aarch64 compilers
```

Check state without a browser:

```sh
curl -s http://127.0.0.1:8765/json | nu -c 'from json | get remote | select clientProcs clientUser impure totals building phase buildElapsed | to json -r'
```

`clientUser` is the evaluation flavour: `root` means `vendorfw` is in play,
`da` means the neutral branch. It comes from the client's environ when readable
and from the `ps` user column otherwise (a sudo client's environ is not).

## Traps that silently disable the alarm

1. **`refresh-target.sh` can write a blank path.** `set -e` does not fire on a
   failed command substitution inside a `printf` argument, and the redirect has
   already truncated the file. A blank `neutral` line is then skipped by
   `loadTargets()`, so a neutral switch classifies as `unknown` and the page
   shows a plain green "DONE — system switched" instead of the red neutral
   warning. Fix pending: capture each probe into a variable, require both
   non-empty, then write the file once. Until then, check the file after running
   it: two lines, both ending in a `/nix/store/...` path.
2. **The client regex must stay anchored.** `nix build .*#nixosConfigurations`,
   never a bare `nix build`: an unrelated build on the Mac keeps the process list
   non-empty and the done gate never fires. `nixos-rebuild` alone covers the
   documented route (on ASAHI that is `nixos-rebuild-ng`, one process for the
   whole run, so its child argv never needs matching).
3. **The remote probe belongs in `probe.sh`.** In a TypeScript template literal
   `'\0'` becomes a NUL byte and `${x#y}` becomes an interpolation; both have
   broken this probe. Check edits with `bash -n probe.sh`, and slice sections with
   `(?=^MARK_|(?![\s\S]))` — a bare `$` under the `m` flag truncates every
   multi-line section at its first line break.
4. **nom hides a zero-valued column.** A fresh build prints only
   `∑ ⏵ 1 │ ✔ 4 │ ⏸ 10 │ ⏱ 30m29s`, so read each figure from its own glyph.
   Counting numbers positionally returns null for hours.
5. **Firmware absence is not failure.** `nix-store -q -R
   /nix/var/nix/profiles/system | awk '/vendorfw/'` can be empty on a correct
   root-flavour switch, because the payload can enter the initrd as embedded
   content. Only a profile that equals the recorded `neutral` path is an alarm.
6. **Verify in a real browser, and read the live DOM first.** Driving
   `render({...})` to test the done branches leaves the fake state in the DOM, so
   a "live" read afterwards reports the last fake. `browser.open` with the
   managed Chromium times out here: pass
   `app: { path: "/etc/profiles/per-user/davr/bin/brave" }`. `fullPage`
   screenshots hang on the animated wavy progress indicator; use the viewport.

## Flavour facts worth re-checking per revision

`expected-target.txt` is per-revision. After a flake change, run
`./refresh-target.sh` (two evals, minutes) or the classification degrades to
`unknown`. Measured on revision 44a9189: the kernel drv
(`6syybn825075ybpbknlh80c2mh381pyb-linux-asahi-7.1.13`) is identical in both
flavours, so a flavour correction after the kernel has built reuses it; only the
initrd and the toplevel differ.
