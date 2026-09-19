---
name: kernel-build-endgame-progress
description: "Read where a nixpkgs kernel build actually is (built-in objects, vmlinux, module objects, modpost, .mod.o, .ko), why log-line and objects/min ETAs collapse there, and the exact denominators to use: modules.order, and the installed module count as an approximation only. Use before promising an ETA on an emulated cross-built kernel, or when a build log looks stalled but is not."
---

# Kernel build endgame: phases, denominators, and honest ETAs

Answer shape: name the phase, name the denominator, refuse the ETA when the
denominator is gone. Verified 2026-09-18 on an aarch64 `linux-asahi` 7.1.13
cross-built on x86_64 with `--print-build-logs`.

## Phases, in order

1. **Built-in objects** — log lines `CC <file>.o` (no `[M]`).
2. **vmlinux link** — quiet: minutes of almost no output under emulation.
3. **Module objects** — log lines `CC [M] <file>.o`. This is the long pass.
4. **One global modpost** — exactly one `MODPOST` line in the whole log.
5. **`.mod.o` compiles** — `CC [M] <file>.mod.o`. Module finalisation, NOT bulk
   object work: seeing `.mod.o` means the module object pass is already over.
6. **`.ko` links** — the module set becomes actual modules.
7. The kernel derivation ends; separate derivations follow: `modules-shrunk`
   (strips/compresses the whole module set, not a minutes-long step),
   `initrd`, boot files, toplevel.

Reading 5 as "still compiling modules" and extrapolating objects/min from it is
the classic error: the denominator changed under you.

## Denominators that hold

- `modules.order` inside the build tree is the exact module list for *this*
  config. It is populated by the modpost step, so it reads 0 before phase 4 —
  that is a pre-modpost artefact, not a missing file.
- The module count of an installed kernel of **another revision** (e.g. a
  running 7.1.12) is an approximation only. Label it as such.
- `.o` counts under the sandbox give a rate during phases 1-3 only.

## Measuring without disturbing the build

Read-only, with sudo, on the builder:

```
sandbox=/nix/var/nix/builds/nix-<pid>-<rand>
sudo find "$sandbox" -name '*.o' | wc -l
sudo find "$sandbox" -name '*.mod.o' | wc -l
sudo find "$sandbox" -name '*.ko' | wc -l        # phase 6; 0 means "not yet"
sudo wc -l "$sandbox"/build/source/build/modules.order
```

Layout: the source tree is `$sandbox/build/source`, and the kbuild output dir is
`$sandbox/build/source/build` — that is where `.config`, `include/config/auto.conf`
and `modules.order` live. Counting from the wrong level returns 0 silently.

**Never run make in a live sandbox.** `make -n` still executes recipes that
contain `$(MAKE)` to propagate the flag to sub-makes, so a "dry run" writes into
a tree another build owns.

## ETA discipline

- Log-line counters and pv bars track phases 1-3; they are meaningless in 4-6
  and during the quiet links, where an instantaneous-rate ETA explodes into
  fictional hours.
- Quote the `.mod.o` rate only as "time to the end of *that* pass", then say
  what still follows (`.ko` links, `modules-shrunk`, initrd, boot files).
- `--print-build-logs` output arrives block-buffered, so line counts jump in
  bursts; a flat minute is not a stall. Sample over a minute or more.

## Client ownership

A build belongs to the client that requested it. If that client exits, Nix
cancels the build — an empty `<drv>.bz2` log appears under
`/nix/var/log/nix/drvs/` and the next waiting client restarts the derivation
from zero (a fresh sandbox with a small object count is the tell). Never leave
two clients racing on one derivation.

For watch-and-notify loops, exiting *is* the notification channel, so run two:
a sentinel-only watcher that never exits early (the finish report must always
arrive) and a stall watcher that exits after a long flat log as early warning.
