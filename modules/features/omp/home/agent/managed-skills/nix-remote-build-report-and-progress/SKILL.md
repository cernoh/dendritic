---
name: nix-remote-build-report-and-progress
description: "Run a multi-hour remote Nix build unattended and report on it: the durable root systemd unit shape, the --collect trap that erases the post-mortem, the report+sentinel phone-home pattern for an agent session, read-only sandbox progress (out-of-tree O= build dir, why make -n is not read-only), pv rate artefacts, and the same-path-two-hosts guard. Companion to nix-long-build-client-ownership, which covers why a build restarts when its client dies."
---

# Unattended remote Nix build: keep it alive, then report on it

Companion to `skill://nix-long-build-client-ownership` (client ownership, cancellation,
the empty `drv.bz2` + fresh-sandbox signature). This skill covers what to run so the
build survives the user walking away, and how to measure and report it honestly.

## 1. One durable client, never two

```sh
systemd-run --unit=HOST-rebuild \
  --property=StandardOutput=file:/tmp/HOST-rebuild.log \
  --property=StandardError=file:/tmp/HOST-rebuild.log \
  --property=OOMScoreAdjust=-800 \
  --setenv=USER=root --setenv=HOME=/root \
  --setenv=PATH=/run/current-system/sw/bin \
  /run/current-system/sw/bin/nix build --impure --keep-going \
    --builders @/etc/nix/machines \
    --option builders-use-substitutes true \
    --print-build-logs --no-link '<flake>#<attr>'
```

- **Do NOT pass `--collect` on the build unit.** systemd unloads a transient unit the
  moment it ends, so a later `systemctl show -p Result --value UNIT` and
  `-p ExecMainStatus` return empty and the report cannot say success versus OOM. Keep
  `--collect` on the *watcher* unit only; clean the build unit later with
  `systemctl reset-failed`.
- **Kill every stray client before starting the unit**, and print how many died. A
  departing client cancels the builds it requested; a second client that was waiting
  re-requests the same derivation immediately, so the build restarts **from zero**.
  Observed cost: a 10,530-object kernel tree abandoned after 3.5 h, fresh sandbox with
  10 objects. Without procps, walk `/proc/*/cmdline` with `tr '\0' ' '` and test
  `[ -r "$d/cmdline" ]` first, or shell redirection errors fill the output.
- Flake argv + `USER=root` keeps firmware-branch derivations identical to a later
  `sudo nixos-rebuild switch`; root under systemd needs
  `git config --global --add safe.directory <checkout>` (libgit2 refuses a repo owned
  by another user), and `git` must exist in the profile (`/run/current-system/sw/bin`).

## 2. Same script path on two hosts

Deploying one script to two machines at `/tmp/x.sh` invites running the wrong copy. Guard
on facts that cannot be faked, before any action:

```sh
[ "$(uname -m)" = aarch64 ] && [ -f /etc/nix/machines ] && [ -d /home/USER/checkout ] \
  || { echo "Refusing to run: this is $(hostname), $(uname -m)."; exit 1; }
```

`whoami` is a fine cross-check when the two hosts use different users.

## 3. Report + sentinel phone-home

Two units: the build, and a watcher that waits for it and writes the report.

```sh
until ! systemctl is-active --quiet HOST-rebuild; do sleep 30; done
{ systemctl show -p Result --value HOST-rebuild
  tail -25 /tmp/HOST-rebuild.log
  grep -n '^error' /tmp/HOST-rebuild.log | head
  USER=root nix build --dry-run --impure '<flake>#<attr>'   # nothing to build = ready
} >/tmp/HOST-report.txt 2>&1
touch /tmp/HOST-done
```

An agent session watches the sentinel and is woken by it:

```sh
ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=4 USER@HOST 'test -f /tmp/HOST-done' && ssh ... 'cat /tmp/HOST-report.txt'
```

Keepalives matter: without them a stalled link hangs the poll loop silently and the
promised notification never fires. The watcher unit is an independent writer, so the
report exists even if the agent session dies.

## 4. Progress, read-only or not at all

- The sandbox tmpdir is `/nix/var/nix/builds/nix-<pid>-<rand>` (root, mode 700) and the
  drv's chroot is `/nix/store/<drv>.chroot`. Neither is readable without root.
- Kbuild runs **out of tree**: `.config`, `include/config/auto.conf` and the objects live
  in the `O=` output dir (for a nixpkgs kernel, `<tmpdir>/build/source/build`), which is
  why `make -C <source>` fails with `include/config/auto.conf: No such file or directory`.
- **`make -n` is not read-only.** GNU make executes recipes containing `$(MAKE)` even
  under `-n`, to propagate the flag to sub-makes, so a "dry run" in a tree a live build
  owns starts real sub-makes. Never do it in a live sandbox. Read-only progress is
  `sudo find <objdir> -name '*.o' | wc -l`, which only rises.
- `path-info` on the drv's outputs answers "is it done" without touching the tree.

## 5. pv ETAs on a build

pv's rate is recent-window, so a bursty feed reads `0.00 /s` between bursts and the ETA
balloons to nonsense (an observed "12 hours" was pure artefact). Feed it continuously:
sample once a second and emit immediately, or emit at most one queued line per second.
Use `-a` for the average rate, `>/dev/null` so the data lines do not shred the bar, and
state the guess: pv caps at 100% and its ETA dies once the line count passes `-s`.
Prefer a real log stream (`--print-build-logs`) over synthesised counters.

## 6. Offload checks that cannot be faked

`--print-build-logs` prints a bare `building '<drv>'` line *in addition* to
`building '<drv>' on 'ssh-ng://…'`, so `grep "^building" | grep -v "on 'ssh-ng://"`
produces a false "local build" for every remote derivation. Decide with:

- client host: no `cc1`/`make`/`gcc` processes and loadavg near zero (`pgrep -c ld` is a
  false positive: kernel threads `kthreadd`/`kthrotld`/`mld` contain "ld");
- builder host: `pgrep -fc qemu-aarch64` (or the native compiler) above zero;
- the log line naming the builder: `on 'ssh-ng://user@address'`.

Also verify preconditions *before* promising speed: `nix path-info --store <cache> <out>`
for the kernel/boot outputs (they are usually absent from community caches even when the
project publishes one), and compare a drv's `requiredSystemFeatures` with the builder's
advertised features, or the work silently stays local.
