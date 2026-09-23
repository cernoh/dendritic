---
name: remote-build-client-detection
description: "Detect and gate on the client of a remote Nix build when watching from the builder side: the CLIENT_RE over- and under-match failure modes (a bare nix build matches unrelated builds and the done gate never fires; a narrow pattern misses nixos-rebuild), reading the eval flavour from ps -o user= when /proc environ is unreadable, the seen-alive latch that survives a manual client restart, and the probe-parsing traps that silently empty a section. Use when a status page or watcher must decide \"the build is over\" for a build whose client runs on another machine."
---

# Deciding "the client is gone" for a remote build

Measured 2026-09-22 watching `nh os switch` on an aarch64 Mac (client) through an
x86_64 builder, from a Deno status page and two standalone watchers. Every trap
below silently broke the completion path, which is the whole point of the page.

## The client pattern has two opposite failure modes

A remote build's client can look like any of these in `ps`, and each has a
different argv:

```
nh os switch . -H ASAHI --impure            the interactive route
nixos-rebuild switch --impure --flake ...   the documented route, as root
nix build .#nixosConfigurations...          nh's child
nix __build-remote N                        the ssh-ng client of the builder
```

- **Too narrow** (`nh os switch|nix build .#nixosConfigurations|nix __build-remote`):
  `nixos-rebuild` never puts `nix build .#nixosConfigurations` in an argv. The
  only remaining hit is the intermittent `nix __build-remote`, so a long local
  tail (initrd, toplevel) yields two empty probes and a false "finished".
- **Too broad** (a bare `nix build`): it matches *any* nix build on that machine —
  a dev shell, `devenv`, an unrelated `nix build .#foo` — and then the gate never
  fires: the page stays BUILDING and no watcher wakes.

The form that covers the documented route without matching everything:

```
CLIENT_RE='nixos-rebuild|nh os switch|nix build .*#nixosConfigurations|nix __build-remote'
```

Check the chosen pattern against **every** route the user might take before you
record it. An over-broad pattern fails silently in the direction that matters
most: the user is never told the build finished.

## An end needs a latch, because a restart looks identical

Killing and relaunching the client by hand produces exactly the signal a finished
build produces: no matching process. So:

- set `seen=1` the first time the client is observed, and only count empty probes
  toward "done" once `seen` is set;
- the same latch belongs in the page server's decide step, or a manual restart
  announces "FINISHED — no switch" for a build that is running.

Also expect a real gap: between a kill and a relaunch the process is absent for
tens of seconds. Two probes 60 s apart is the shortest safe window.

## The evaluation flavour is not the process user

A client started with `sudo` (the `nixos-rebuild` route) is root-owned, so
`/proc/<pid>/environ` is unreadable by the page's ssh user. A client started as
`da` with `env USER=root` has `da` as its process user while the evaluation reads
`USER=root`. Read both and prefer the environment value when it is readable:

```sh
ps -eo pid,etimes,user,args        # user column survives sudo
for p in $(pgrep -f "$CLIENT_RE"); do ... read USER= from /proc/$p/environ ...; done
```

`clientUser = envUser ?? psUser`. Emit exactly one value: `pgrep -f` matches
several processes, so a per-pid `echo USER=...` loop yields several lines, and a
consumer that strips the `USER=` prefix from the first line only then compares
against `"root"` fails. Take the first non-empty line, or dedupe in the probe.

## Probe parsing traps that empty a section

- **Keep the shell in its own file.** `probe.sh` fed over ssh stdin, not a string
  inside a TypeScript template literal. Measured failures from that layer:
  `'\0'` became a NUL byte (a `tr '\0' '\n'` env read returned nothing), and
  `${kv#USER=}` became an interpolation and broke the parse outright. Check the
  file with `bash -n`; a separate file is also editable and testable alone.
- **Slice by marker with a line-anchored pattern, and end it at the next marker
  or the true end of input:**
  `new RegExp("^MARK_" + name + "\\n([\\s\\S]*?)(?=^MARK_|(?![\\s\\S]))", "m")`.
  A bare `$` in that lookahead matches at *every* line end under the `m` flag, so
  each multi-line section collapses to its first line — the symptom is a pane
  capture of one junk line and `null` for every parsed field, while the remote
  probe output is perfectly correct.
- **An awk that greps `ps` output matches itself.** `ps -eo args | awk '/nix
  build/ {c++} END {print c+0}'` counts one extra. Add `!/awk/`.
- **Read a summary line by glyph, not by column position.** nom drops a column
  whose count is zero, so a fresh build prints only
  `∑ ⏵ 1 │ ✔ 4 │ ⏸ 10 │ ⏱ 7m56s`. A positional `(\d+){8}` pattern returns null
  for hours. Use `/⏵\s*(\d+)/`, `/✔\s*(\d+)/`, `/⏸\s*(\d+)/`, `/⏱\s*(\S+)$/`.
- **`ps` output is your only cross-check when ssh returns nothing useful.** Print
  the raw probe output once by hand (`awk` the script out of the server and pipe
  it to `ssh host bash -s`) before you trust any parsed field.

## Prove the outcome with the profile, not with an incidental path

- The decisive signal is the activated profile matching the expected output path
  of the intended flavour. Compare `readlink -f /nix/var/nix/profiles/system`
  against recorded per-flavour targets.
- A closure query (`nix-store -q -R /nix/var/nix/profiles/system | awk
  '/vendorfw/'`) is *extra evidence*, never an alarm: firmware can enter a
  generation as embedded content through a builder step rather than as a
  store-path reference, so absence proves nothing. Report it when found; do not
  turn red on absence.
- A moved profile does not prove the boot or firmware write ran: an activation
  step runs after the profile moves, and an ESP failure leaves the profile moved.

## Verify before claiming the page works

Drive the terminal state by calling the page's own `render()` with a fabricated
snapshot for each branch. Two rules:

- read the live DOM **before** driving any fake state, or the "live" numbers you
  report are whatever the last fake left behind (measured: a live read after four
  fakes reported the neutral-flavour banner as if it were real);
- a browser `screenshot({ fullPage: true })` can time out on a page with an
  animated indicator, because the capture waits for stability. Use a viewport
  shot, or accept the DOM assertions as the proof.
