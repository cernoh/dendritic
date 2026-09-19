---
name: nix-emulated-build-eta-timer
description: "Build a non-lying ETA timer for a long Nix build on an emulated remote builder (aarch64 on x86_64): pv artifacts that fake a multi-hour ETA, why counting object names is wrong, what to count instead, and stop conditions that do not fire during the copy-back gaps. Complements nix-emulated-build-progress-timer, which covers where the real object count lives."
---

# A build timer that does not lie

Goal: a rough but stable ETA for an emulated remote Nix build, from the requesting
host, with no root and no access to the builder's sandbox.

## The artifacts that make a timer lie

1. **Bursty feed makes pv's ETA explode.** `pv -e` uses its *recent* rate. A script
   that samples the fleet every 20 s and dumps the sample into `pv` shows
   `0.00 /s` between bursts, and pv extrapolates from that silence to hours. A
   run that is 8 minutes from done reported `ETA 12:00:00`. Use `-a` (average
   rate) and pace the emission at roughly one line per second.
2. **Counting object names counts the wrong thing.** `ps` command lines expose
   `-o /build/ccXXXXXX.s` assembler temporaries, whose names are new for every
   invocation, next to the real `-o arch/.../foo.o`. A name-set timer therefore
   advances on temp churn at about twice the object rate. If names are needed at
   all, match `-o \([^ ]*\.o\) ` only, and expect to miss objects whose `as`
   stage is shorter than the sample interval.
3. **pv is a pass-through.** `... | pv -l -s N -p -t -e` writes the counted lines
   to stdout, so they interleave with the bar on the same tty and shred it.
   Append `>/dev/null`.
4. **The guess caps and silences the bar.** `-s` fixes pv's denominator for the
   whole run. Once the line count passes it, the bar pins at 100% and the ETA is
   gone. Take the guess as an argument, default it high, and print a notice at
   exhaustion.
5. **An idle-stop fires in the copy-back gaps.** Remote builds go qemu-free
   while outputs travel back to the requester between derivations, for minutes
   at a time. A local "no emulated process for 3 samples" rule ends the timer
   while half the plan is still ahead. Either require ~12 consecutive idle
   samples, or gate the stop on the requester (`ssh RUNNER pgrep -f 'nix build'`,
   or a sentinel file the runner's own watcher writes).

## What to count

The whole build is emulated, so *every* tool it runs appears as a foreign-arch
process: `cc1`, `as`, `ld`, `make`, `sed`, `sh`. Counting **process starts**
(`pgrep <foreign-arch-qemu>` PID set growth) is monotonic, immune to temp-name
churn, and keeps counting through the link and module phases. It measures
throughput, not objects, which is all an ETA needs.

Measured on an 8-core/16-thread x86_64 host with 8 emulated jobs: about **155 new
emulated processes per minute** (~2.6/s) with ~72 live. Use that as the unit for
the guess: a 5000-line bar is roughly 32 minutes at that pace.

## Shape that worked

```fish
set -l guess 5000            # from $argv[1]; lines to expect
set -l seen (pgrep qemu-aarch64)
while true
    test (pgrep -c qemu-aarch64) -eq 0; and set idle (math $idle+1) || set idle 0
    test $idle -ge 12; and break
    for p in (pgrep qemu-aarch64)
        contains -- $p $seen; and continue
        set -a seen $p
        echo o
        sleep 1              # pace: one line per second keeps pv's rate alive
    end
    sleep 15
end | pv -l -s $guess -p -t -e -a >/dev/null
```

Count the running total into a file inside the piped block: the loop runs in a
pipeline (forked), so a variable set there never reaches the parent shell, and a
final `count $seen` prints only the priming value.

## Cross-check with the requester

The timer is a pace display only. The authoritative end signal lives where the
client runs: a watcher on the requester that waits for the build client to exit
and then writes a report (log tail, error lines, remote-built count, and a
`--dry-run` of the target that must report nothing left to build). A dry run with
no builds and no fetches is the only proof that the whole closure is present; a
quiet builder also happens when a build *failed*.
