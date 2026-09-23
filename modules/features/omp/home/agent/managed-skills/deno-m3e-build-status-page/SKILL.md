---
name: deno-m3e-build-status-page
description: "Serve a Deno + @m3e/web status page for a long remote Nix build (ASAHI client on NIXPC builder): vendored M3E bundle and subset icon font, nom pane parsing traps, the nh os switch completion gate, and the real-browser verification recipe. Use when asked for a watch page or a completion alert for a running build."
---

# A Deno + M3E status page for a remote Nix build

Measured on NIXPC, 2026-09-22, watching `nh os switch` on ASAHI (aarch64) build
through NIXPC as the remote builder. Complements `nix-remote-build-status-page`
(Python, nom-agnostic) with the Deno + Material 3 Expressive version and the
parsing traps that version hit.

## Topology decides where the signals live

- Client on the Mac: `nh os switch` inside tmux. Work on the builder: this host.
- Builder-side signals are local and need no root: `pgrep -fc qemu-aarch64`,
  and per-object progress from `/proc/<pid>/cmdline` (`-o <file>.o` appears in
  the gcc driver and `as` invocations, so dedupe the set — 75 qemu processes
  are about 15 distinct objects).
- The kernel build log is **not** readable live: the builder writes
  `/nix/var/log/nix/drvs/<xx>/<drv>.bz2` as a 0-byte placeholder at start and
  fills it at the end. Derivation-completion rate (count of `.bz2` with mtime
  after the client start) is the only honest "derivations done" counter, and it
  goes flat for hours during the kernel — never read that as a stall.
- One ssh per refresh, script over stdin: `ssh host bash -s` with the probe on
  stdin. The login shell on the Mac is **fish**, so a compound command line
  breaks on globs (`/tmp/nh-*/result`) and on `uptime -p`.

## Parsing nom's pane: strip in two passes, not one

`tmux capture-pane -p -t 0 -S -80` is the best client-side progress source, but
a single strip set makes the summary line unmatchable. Measured trap: a
box/glyph strip that removes `∑ ⏵ ✔ ⏸ ⏱ ↓ ↑` leaves
`1 348 10 0 457 0 0 4 1h12m22s`, so a pattern anchored on `^∑` can never match
and `totals` stays `null` (the wavy bar then sits indeterminate for hours).

Use two variants of the same line list:

```ts
const BOX_DRAW = /[│┃┌┐└┘├┤┬┴┼━─╭╮╰╯┏┓┗┛┣┫┳┻╋·]/g; // frame only
const GLYPH    = /[∑✔⏸⏵⏱↓↑]/g;                      // nom's own glyphs
const flatBox = lines.map(l => l.replace(BOX_DRAW, "").trim());  // keeps ∑
const flat    = flatBox.map(l => l.replace(GLYPH, "").trim());   // for names
```

- Current derivation: match `flat` with `^(\S+) on (\d+) \((\w+)\)\s+(\S+)$`
  (the `⏵` prefix must already be gone).
- Totals: match `flatBox`, and take the numbers positionally — the glyphs sit
  *between* them, so a positional pattern on the glyph-stripped variant is the
  robust form: `/^((?:\d+\s+){7}\d+)\s+(\S+)$/` over `flat`, or read the first
  eight `\d+` matches and the `⏱`-suffixed clock separately.
- Line shape: `∑ ⏵ 1 │ ✔ 348 │ ⏸ 10 │ ↓ 0 │ ↓ 457 │ ⏸ 0 │ ↑ 0 │ ↑ 4 │ ⏱ 1h24m44s`
  = running, built, waiting, downloads now/done, queued, uploads now/done,
  elapsed. It is the page's only real "how far along" signal.

## Completion gate: the whole client, not the build child

`nh os switch` builds as the user and then activates as root, and after a
multi-hour build the sudo timestamp is long expired — the pane sits at a
password prompt. So gate DONE on every client process, and surface the prompt:

- Probe `ps -eo pid,etimes,args` and keep lines matching
  `nh os switch|nix build .#nixosConfigurations|nix __build-remote`.
  DONE requires **all** of them gone for two consecutive probes; a gate on the
  `nix build` child alone announces success before anything is switched.
- The first line's `etimes` is the client start time; use it for the
  derivations-since-start counter, and run the ssh probe **before** the local
  counters or the first refresh counts zero.
- Warn when the pane shows `password for`/`[sudo]`, and when
  `/nix/var/nix/profiles/system` did not change: "finished without a switch".
- Distinguish switched from not-switched by that profile path, never by the
  presence of a result link.

## Field names are the silent-failure class

The page reads camelCase from `/json`; the server must emit the same. Measured
misses that rendered as "?" or never fired: `build_elapsed` vs `buildElapsed`,
`sudo_prompt` vs `sudoPrompt`, `battery_status` vs `batteryStatus`. Check every
key the page reads against the live `/json` in the browser pass.

## Vendor the UI so the page needs no CDN

- `@m3e/web@2.8.2` bundle: `https://cdn.jsdelivr.net/npm/@m3e/web@2.8.2/dist/all.min.js`
  (1.3 MB), served from disk as `text/javascript`.
- Icon font: request a **subset** from the Fonts CSS API —
  `...family=Material+Symbols+Outlined:opsz,wght,FILL,GRAD@24,400,0..1,0&icon_names=battery_full,bolt,...`
  with a Chrome UA, then fetch the `woff2` it names and rewrite `url(...)` to a
  local path. Ten icons weigh 3 KB instead of megabytes.
- Tag and attribute names: do **not** guess from module names, and do not grep
  the minified bundle (the grep tool returns whole minified lines). Fetch the
  per-component READMEs — `https://raw.githubusercontent.com/matraic/m3e/HEAD/packages/web/src/<component>/README.md`
  — for exact tags, attributes, variants and slots. The bundle registers with
  the minified decorator `Pi("m3e-…")`; a token-splitting pass over it also
  yields the full tag list.
- Verified shapes: `<m3e-theme color="#a1795a" variant="expressive" scheme="auto" motion="expressive" strong-focus>`
  directly under `<body>`; `m3e-linear-progress-indicator variant="wavy" mode="determinate" value="97"`;
  `m3e-card variant="outlined"` with `header`/`content`/`actions`/`footer` slots;
  `m3e-app-bar size="small"` with `leading`/`title`/`subtitle`/`trailing`;
  `m3e-heading variant=display|headline|title|label`; `M3eSnackbar.open(msg, true)`.

## Serve and verify

- Deno from the store, no PATH: `nix shell nixpkgs#deno -c deno run -A server.ts`;
  `deno check server.ts` first — it caught three real bugs (missing return
  field, a leftover `Map.get`, `Uint8Array` not being `BodyInit`; serve `Blob`).
- `hub start` fails when the omp broker is down: launch with `setsid nohup` and a
  restart loop whose `pkill` patterns live **inside** the script file.
- Bind `0.0.0.0`; hand `http://127.0.0.1:8765/` to the desktop and the tailnet
  IP to a phone (Brave's HTTPS-First breaks a bare `http://<ip>`).
- Verify in a real browser, never by grepping served HTML: the state lives in
  shadow roots. Check `document.body.dataset.m3e === "ready"` (set from
  `customElements.whenDefined("m3e-button")`), that every `m3e-card` has a
  `shadowRoot`, the computed `--md-sys-color-primary`, and the live card text.
  `browser.open` with the managed Chromium timed out here — pass
  `app: { path: "/etc/profiles/per-user/davr/bin/brave" }`.
- Drive the terminal state without waiting for it: call the page's own
  `render({state:"done", detail:"switched", …})` and assert the banner colour,
  icon name, `prog` value `100`, snackbar text and tab title.
- Wake the agent independently of the page: a `sentinel` watcher that exits only
  when all client processes are gone (or ASAHI has been unreachable for 10
  probes), plus a `stall` watcher labelled a warning. Run both with
  `async: true, timeout: 0`.
