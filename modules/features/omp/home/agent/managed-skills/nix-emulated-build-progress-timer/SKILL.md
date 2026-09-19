---
name: nix-emulated-build-progress-timer
description: "Measure progress of a long Nix build running on a remote builder (emulated aarch64 on x86_64): why no live log or readable sandbox exists without the right path, the exact remaining-object count via make -n ARCH=arm64, and a pv-based timer driven by sampling the compiler fleet. Use when a remote build runs for hours and the user asks for progress, a percentage, or an ETA."
---

# Progress of a long remote Nix build

A build offloaded to a remote builder gives no live log and no percentage. These
are the only three signal sources, in order of value.

## 1. The requester's log has one line per derivation

The client that asked for the build prints one `building '…drv' on 'ssh-ng://…'`
line per derivation. A kernel is one derivation, so nothing appears for hours.
The log stream itself is sent to that client; another client cannot attach, and
`-L`/`--print-build-logs` must be set when the build starts to capture it.
Start long builds with `-L` for a future-readable log.

## 2. On the builder, only the compiler fleet is visible

`nix log <drv>` prints nothing until the derivation finishes: the daemon holds
the log and writes `/nix/var/log/nix/drvs/…bz2` at the end. The daemon journal
has no per-build lines. The sandbox is `drwx------ root root`, so `stat` and
`readlink /proc/<pid>/cwd` fail with `EACCES` for a normal user.

Live signals that do work:

```sh
pgrep -fc qemu-aarch64                                   # busy emulated compilers
pgrep -af qemu-aarch64 | sed -n 's/.* -o \([^ ]*\).*/\1/p' | tail -3
```

The second command names the objects being compiled, which shows the phase:
`.o` files are the object sweep, `vmlinux`/`vmlinux.o` the link, then the module
pass. In the standard `vmlinux-dirs` order the last large groups are `drivers/`,
`sound/`, `net/`, with only `lib/` and `arch/arm64/lib/` before the link.

## 3. Exact remaining objects, from the sandbox with sudo

The sandbox root in `/nix/var/nix/builds/nix-<pid>-<rand>/` contains `source/`,
not the kbuild root, so `<sandbox>/build/Makefile` does not exist even though
`build/` is readable with sudo.

```sh
sudo ls /nix/var/nix/builds/nix-<pid>-<rand>/build/     # find the source root
sudo env PATH="$PATH" make -C <source-root> -n ARCH=arm64 vmlinux modules \
  2>/dev/null | sed -n 's/.* -o \([^ ]*\.o\).*/\1/p' | sort -u | wc -l
sudo find <source-root> -name '*.o' | wc -l             # already compiled
```

Traps, all observed:

- `ARCH=arm64` is mandatory. Without it the top Makefile takes `SUBARCH` from
  `uname -m`, evaluates the host architecture graph and prints a large
  meaningless number instead of failing.
- `sudo make` fails with `make: command not found`: sudo resets PATH and drops
  `/run/current-system/sw/bin`. Use `sudo env PATH="$PATH" make` or
  `sudo "$(command -v make)"`.
- `-n` runs no recipe, but kernel Makefiles expand `$(shell …)` probes. The walk
  takes minutes; do not add `-j` and do not run it with the tree otherwise busy.
- Pass only `-n`, never `-s`, or the recipes you want to count are suppressed.
- Add the `.o` count already on disk for the total.

## 4. A pv timer over the compiler fleet

pv needs one line per finished unit. Sample the fleet every 20 s, emit one line
per newly seen `-o` target, and let pv compute rate and ETA:

```fish
set -l guess 800
set -l seen (pgrep -af qemu-aarch64 | sed -n 's/.* -o \([^ ]*\).*/\1/p' | sort -u)
while true
    if test (pgrep -c qemu-aarch64) -eq 0
        set idle (math $idle + 1); test $idle -ge 3; and break
    else
        set idle 0
        for f in (pgrep -af qemu-aarch64 | sed -n 's/.* -o \([^ ]*\).*/\1/p' | sort -u)
            if not contains -- $f $seen
                set -a seen $f
                echo o
            end
        end
    end
    sleep 20
end | nix run nixpkgs#pv -- -l -s $guess -p -t -e -r > /dev/null
```

Facts that make it trustworthy:

- Prime `seen` before the loop, or the first sample arrives as one burst of ~70
  lines and poisons pv's rate for minutes.
- Measured discovery rate: about 56 new object names per minute when 8 emulated
  jobs on a 16-thread machine run 74-79 concurrent compilers (load ~20).
- pv is a pass-through. Without `> /dev/null` it copies every `o` line to the
  terminal and shreds the display.
- pv caps at 100% once the emitted count passes `-s`, so a low guess makes a
  running build look finished. Default `-s` high, or print a "guess exhausted"
  notice when the count reaches it.
- pv suppresses its display when stderr is not a tty (`/tmp/pv.err` stays empty);
  add `-f` when capturing, and nothing when a user watches a real terminal.
- A `while … end | cmd` loop runs forked: `set -a seen` never reaches the parent
  shell, so a post-pipeline `count $seen` prints only the priming value. Report
  the summary from inside the piped block, or write it to a file.
- Stop rule: emulated phases keep the fleet busy, so "no qemu processes for three
  samples" is a fair finish test. The copy of outputs back to the requester
  happens after that and is not emulated.

## Expectation to set with the user

A linux-asahi kernel under emulation took about 3 hours on a 16-thread Ryzen
3700X with 8 jobs, and the object sweep was still in `drivers/`/`net/` at that
point, with the link, modules and initrd still ahead. A whole aarch64 system
build (178 derivations) leaves the kernel as the only long pole; every other
derivation lands in the requester's store long before it.
