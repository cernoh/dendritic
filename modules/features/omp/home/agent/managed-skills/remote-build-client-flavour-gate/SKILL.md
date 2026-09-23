---
name: remote-build-client-flavour-gate
description: "Decide whether a remote Nix build will produce the system the documented switch expects, and gate a watcher's DONE on real evidence: the USER-flavour gate (getEnv \"USER\" == \"root\"), why --impure alone is not enough, measured flavour deltas, and the probe/watcher traps that silently falsify status."
---

# The client flavour gate, and DONE gates that do not lie

Measured 2026-09-22 on ASAHI (aarch64 Mac) building through NIXPC (x86_64) as
remote builder, while watching `nh os switch` from a Deno status page.

## The flavour gate: `--impure` is not the lever, `USER` is

A flake may branch on the *evaluating user* to include host-only payloads:

```nix
evalSystem  = builtins.currentSystem or null;
onMacAsRoot = evalSystem == "aarch64-linux" && builtins.getEnv "USER" == "root";
vendorfw    = if onMacAsRoot then /boot/vendorfw else null;
...
hardware.asahi.peripheralFirmwareDirectory = vendorfw;
hardware.asahi.extractPeripheralFirmware   = onMacAsRoot;
```

Consequences, all measured on the same revision:

| | client as `da` (even with `--impure`) | client as root flavour |
|---|---|---|
| toplevel drv | `7bk0a4wl…` | `5mw77z528…` |
| toplevel output | `65bb08gq…` | `b6xs9pbhnz0626lv8cc5g2b1nknvk5nn…` |
| initrd drv | `if800nnq…` | `jdw0byv5…` (embeds the firmware payload) |
| `peripheralFirmwareDirectory` | `null` | `/boot/vendorfw` |
| kernel drv | `6syybn825075ybpbknlh80c2mh381pyb-linux-asahi-7.1.13` | **identical** |

- `--impure` only decides whether `getEnv` is readable at all. Under pure eval it
  returns `""`, so the neutral branch is guaranteed; with `--impure` and
  `USER=da` it is still neutral. Only `USER=root` reaches the root branch.
- **The kernel drv is identical across flavours.** So restarting in the right
  flavour does not repeat the expensive kernel compile — a wrong-flavour build
  caught while the kernel is still compiling costs almost nothing, and catching
  it late costs only the initrd and the tail.
- The root flavour is reachable **without root rights**: `env USER=root nix eval
  --impure …` from the flake owner resolves the root toplevel, and the Nix daemon
  (which runs as root) copies `/boot/vendorfw` into the store — verified by the
  presence of a `*-vendorfw` store path containing `firmware.cpio` (~32 MB),
  `firmware.tar`, `manifest.txt`, `u-boot/`. Non-root `builtins.pathExists` on
  `/boot/vendorfw` throws, which is why the flake gates on the user instead.

Right commands, both producing the root flavour:

```sh
env USER=root nh os switch . -H ASAHI --impure          # nh 4.4.2: --impure is first-class
sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI   # sudo sets USER=root
```

Check a *running* client before trusting it: `ps -o args` for the command and the
client env for `USER`. A client that shows `--impure` but `USER=da` is neutral.

## Gate DONE on evidence, never on "no process seen"

1. **Require a live sighting before any end.** A manual restart (client killed,
   relaunched a minute later) is indistinguishable from a finished build to two
   empty probes. Keep a latch that is set when a client is seen and only let
   `done` be declared after it. Verify the latch is actually wired: the variable
   must be both assigned *and* read (`grep -n seen watch.sh`) — an unused latch
   variable is a silent no-op.
2. **Match every client shape.** `nix build .#nixosConfigurations` is absent from
   `nixos-rebuild`'s argv, so a matcher built on it sees only the intermittent
   `nix __build-remote` and reports FINISHED during a long local tail. Use
   `nixos-rebuild|nh os switch|nix build|nix __build-remote`.
3. **Prefer `ps -o user=` over `/proc/<pid>/environ`** for the client's user:
   `/proc/<pid>/environ` is unreadable once the client runs under `sudo`.
4. **Name the flavour of what was activated**, not just "the profile moved".
   Record both flavours' toplevel outputs for the current revision and compare
   `readlink -f /nix/var/nix/profiles/system` against them; or check
   `nix-store -q -R /nix/var/nix/profiles/system` for the `*-vendorfw` store
   path. Red when the switch landed on a system without the payload.
5. **Do not claim a step ran from the profile alone.** `switch-to-configuration`
   moves the profile before the boot/ESP steps, so an ENOSPC or failed ESP write
   still looks green. Say "vendorfw included in this generation" unless you
   verify the payload on the ESP afterwards.

## Probe plumbing traps (each cost a silent wrong reading)

- **Never put the remote script in a JS/TS template literal.** `'\0'` becomes a
  NUL byte and `${kv#USER=}` becomes interpolation (a syntax error). Keep it in a
  sibling `probe.sh`, `Deno.readTextFile` it, and feed it on stdin — a plain
  shell file can be syntax-checked on its own.
- **Section splitting:** parse `^MARK_NAME\n([\s\S]*?)(?=^MARK_|(?![\s\S]))` with
  the `m` flag. A bare `$` in that lookahead matches at *every* line end under
  `m`, truncating each multi-line section to its first line — which shows up as
  "the pane is one junk line" and null `building`/`batteryStatus`.
- **`awk` self-match:** `ps | awk '/pattern/ {c++}'` counts the `awk` process
  itself. Add `!/awk/`.
- **nom hides zero-valued columns.** A fresh build prints
  `∑ ⏵ 1 │ ✔ 4 │ ⏸ 10 │ ⏱ 5m25s`; a later one prints the full
  `∑ ⏵ 1 │ ✔ 348 │ ⏸ 10 │ ↓ 0 │ ↓ 457 │ ⏸ 0 │ ↑ 0 │ ↑ 4 │ ⏱ 1h12m22s`. Parse each
  figure from its own glyph (`⏵` running, `✔` built, `⏸` waiting, `⏱` elapsed),
  never by column position.
- **A derivation ratio is not progress.** One running derivation (the kernel) can
  be hours while the bar reads 97%; label it "N built · N running · N pending"
  and keep the running derivation's elapsed time on screen.
- **Exit-code traps in shell loops:** `pgrep -fc X` prints `0` *and* exits 1 when
  nothing matches, so `x=$(pgrep -fc X || echo 0)` yields `0\n0`. Use
  `comp=$(pgrep -fc X 2>/dev/null || true); comp=${comp:-0}`.

## Verifying the page itself

The managed Chromium prelude can time out; on this host open the page through the
system Brave with an explicit path:

```js
const t = await browser.open({ url, app: { path: "/etc/profiles/per-user/davr/bin/brave" } });
```

Assert `document.body.dataset.m3e === "ready"`, one upgraded card per signal
(`[...document.querySelectorAll("m3e-card")].every(c => c.shadowRoot)`), and read
values out of the light DOM. Prove the terminal branch without waiting hours by
calling the page's own `render()` with a synthetic snapshot for each outcome
(root flavour, neutral flavour) and reading the headline, colour and footer back.
A `fullPage` screenshot can time out on an animated wavy progress indicator; take
a viewport capture instead.
