---
name: nix-remote-build-progress-and-offload-flags
description: "Read a remote Nix build's real progress and make a host actually offload: why the requester prints one line per derivation, why the builder's log and sandbox are unreadable mid-build, the sudo make -n ARCH=arm64 object count, and the compiled default of the builders setting that decides whether /etc/nix/machines is used at all"
---

# Remote build progress and the builders flag

Companion to `skill://nixos-remote-builder-offload-diagnosis` (the `@file` override,
`distributedBuilds`, detached client) and `skill://dendritic-asahi-cross-build` (the
link itself: key, host key, `big-parallel`, tailnet address). This skill covers the two
questions those do not answer: *is it offloading at all*, and *how far along is it*.

## 1. The `builders` setting decides whether /etc/nix/machines is read

`/etc/nix/machines` existing is not evidence that the daemon uses it.

- Old nixpkgs rendered `builders = ` (empty) when `nix.distributedBuilds = false`, and
  `builders = @/etc/nix/machines` when true. An empty value *disables* the machines file.
- Newer nixpkgs (`nixos/modules/config/nix-remote-build.nix`) only sets
  `nix.settings = mkIf (!cfg.distributedBuilds) { builders = null; }`. With
  `distributedBuilds = true` it leaves the setting untouched, so the *compiled default*
  applies.
- On Nix 2.34.8 that default is `@$NIX_CONF_DIR/machines`, i.e. `/etc/nix/machines`.
  Prove it without touching the system:

```sh
mkdir -p /tmp/emptyconf && touch /tmp/emptyconf/nix.conf
NIX_CONF_DIR=/tmp/emptyconf NIX_USER_CONF_FILES=/dev/null nix config show builders
# -> @/tmp/emptyconf/machines
```

Consequences:

- A host whose **running** generation still carries `builders = ` empty rebuilds
  everything locally (with `max-jobs = 1; cores = 1` on an OOM-guarded laptop/Mac, that
  is a multi-hour kernel compile) even though the flake sets `distributedBuilds = true`.
  The first switch needs the per-command override:

```sh
sudo nixos-rebuild switch --impure --flake /path/to/flake#HOST \
  --builders '@/etc/nix/machines' --option builders-use-substitutes true
```

- `nixos-rebuild-ng` does accept `--builders BUILDERS` and `--option OPTION OPTION`
  (verified in `--help`). A *wrapped paste* that breaks the line after `--option` fails
  with `nixos-rebuild: error: argument --option: expected 2 arguments`, and fish then runs
  the orphaned word as a command. Give such a line as a script, not as one long paste.
- `--builders-use-substitutes` is not a flag; use `--option builders-use-substitutes true`.
  At activation time, when the outputs are already in the store, the option is irrelevant
  (nothing is uploaded).

Unconfirmed until observed: that the switched generation needs no flag on the next
rebuild. Confirm with `nix config show builders` *on the switched generation*, not from
the flake.

## 2. There is no live log for a build that is running elsewhere

- The **requester** writes one line per *derivation*. A kernel is one derivation, so the
  log shows `building '…-linux-asahi-….drv' on 'ssh-ng://…'` and then nothing for hours.
  Per-file progress exists only with `-L`/`--print-build-logs`, and you cannot attach that
  to a build another client already started.
- The **builder** keeps the derivation log only after the derivation finishes:
  `nix log <drv>` prints `got build log for '…' from 'daemon'` and nothing while it runs.
  The daemon journal carries no per-build lines (only `accepted connection … (trusted)`).
- The **sandbox tree** is opaque from outside: `/nix/var/nix/builds/nix-<pid>-<rand>/` is
  mode 700 root, and even `stat` on `build/` returns `Permission denied` for a normal user.
  With sudo the layout is `$TMPDIR/<source>/` — the kbuild root is one level *below*
  `build/`, so `build/Makefile` does not exist. Find it with
  `sudo ls /nix/var/nix/builds/nix-<pid>-<rand>/build/`.

Sudo resets PATH, so `sudo make` fails with `make: command not found`. Use
`sudo env PATH="$PATH" make …` or `sudo "$(command -v make)" …`.

## 3. The only exact progress number

Object count and remaining work, both against the real kbuild root `$SRC`:

```sh
sudo find /nix/var/nix/builds/nix-<pid>-<rand>/build/$SRC -name '*.o' | wc -l
sudo env PATH="$PATH" make -C /nix/var/nix/builds/nix-<pid>-<rand>/build/$SRC \
  -n ARCH=arm64 vmlinux modules 2>/dev/null |
  sed -n 's/.* -o \([^ ]*\.o\).*/\1/p' | sort -u | wc -l
```

- `ARCH=arm64` is mandatory. Without it the top-level Makefile takes `SUBARCH` from
  `uname -m`, evaluates the host-architecture graph, and returns a large meaningless
  number instead of failing.
- Pass `-n` only, no `-j`: it shares the tree with the running build, recipes print but
  do not run (some `$(shell …)` probes do, read-only).
- `vmlinux` alone omits the objects the `-modules` derivation compiles; ask for both.
- Budget minutes for the graph walk on a loaded machine.

## 4. Cheap live signals, and the trap in them

```sh
pgrep -fc qemu-aarch64                                   # emulated compilers busy; 0 = idle
pgrep -af qemu-aarch64 | sed -n 's/.* -o \([^ ]*\) .*/\1/p' | tail -3   # what compiles now
```

Phase position reads better than a number: in the standard `vmlinux-dirs` order the last
large groups are `drivers/`, `sound/`, `net/`, then only `lib/` and `arch/<arch>/lib/`
before the link. Seeing those trees means the object phase is nearly over. After it come
the link (`-o vmlinux.o`), the module pass, `modules-shrunk`, `initrd`, the boot files,
and the copy back.

**Do not extrapolate a concurrency sample into a count.** Sampling distinct in-flight
targets over a window measures how many jobs are saturated, not a completion rate: with
74 emulated processes on 16 cores the distinct count barely exceeds the in-flight count,
which says nothing about throughput. A rate derived this way once produced an estimate
larger than any plausible total for the object set.

"The compilers went quiet" also happens when a build *fails*. Confirm success from the
requester: a `--dry-run`/`--realise` of the same derivation with no builders, which must
report nothing left to do.

## 5. Notify me when it finishes (durable, survives disconnects)

Start a watcher on the target that waits for the client argv, then writes a report and a
sentinel; poll the sentinel from the agent session so the completion is delivered as a job
result rather than watched.

```sh
while pgrep -f 'nix build --impure' >/dev/null; do sleep 30; done
# then write: log tail, '^error' lines, count of lines matching "on 'ssh-ng", drv path,
# and a --dry-run of the toplevel with no builders (nothing to build == closure complete)
echo ok > /tmp/<host>-build-done
```

Verify the gate before trusting it: `pgrep -af 'nix build'` must show the live client
argv, and the sentinel must be absent while the build runs. A pattern that matches nothing
writes the sentinel on the first iteration and reports a false finish.

## 6. Disk, before the copy lands

The requester copies the closure back when the build ends. Check its free space while the
build still runs, and size the copy instead of guessing: a `--dry-run` of the target with
`USER=root` prints `these N derivations will be built` and, only if downloads are needed,
`these M paths will be fetched (X MiB download, Y MiB unpacked)`.

Ordering that matters: build clients started with `--no-link` hold **no GC root** until the
switch creates the generation, so a `nix-collect-garbage` between build completion and
`nixos-rebuild switch` collects the just-copied outputs. Collect *before* the build ends or
*after* the switch, never in between.
