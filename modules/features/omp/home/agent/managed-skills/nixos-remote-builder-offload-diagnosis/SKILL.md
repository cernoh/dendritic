---
name: nixos-remote-builder-offload-diagnosis
description: "Make a NixOS host actually offload a build to a remote builder and keep it alive for hours: the inert machines file without nix.distributedBuilds, the --builders '@file' override, the root-unit libgit2 safe.directory trap, client-exit cancels that restart a build from zero, the durable systemd-unit client with a report sentinel, and honest read-only progress from inside the sandbox. Use when \"local builds are disabled (max-jobs = 0)\" appears, when a builder is configured but jobs build locally, or before starting a multi-hour build on a constrained host."
---

# NixOS host will not offload builds to a remote builder

## Symptom
A host that should ship work to a builder compiles everything itself, or nix dies with:

```
Reason: local builds are disabled (max-jobs = 0)
Hint: ... or configure remote builders via 'builders'
```

even though `/etc/nix/machines` exists and the builder was restarted. Classic victim:
a laptop/desktop pinned to `max-jobs = 1; cores = 1` (OOM guard), where "one job" means
a single-threaded multi-hour kernel/rustc compile.

## Fact 1: the machines file is inert without `nix.distributedBuilds = true`
NixOS's nix-daemon module only points the `builders` setting at the machines file when
the option is on. `nix.distributedBuilds = false` (the default) renders `builders = `
(empty), and the daemon then never consults `/etc/nix/machines`. Writing the file by hand
and restarting `nix-daemon` changes nothing — the running system must be re-switched, or
the builders must arrive from the client.

Check the switch is actually in the running system, not just the flake:

```sh
nix config show builders                 # empty => file inert
grep -E '^builders' /etc/nix/nix.conf    # 'builders = ' => inert, absent line => default
cat /etc/nix/machines                    # may exist and be correct
```

**Recent nixpkgs reverses the render** (`nixos/modules/config/nix-remote-build.nix`):
it sets `builders = null` only when `distributedBuilds = false`, and otherwise leaves the
setting alone. Nix's compiled default is then `@$NIX_CONF_DIR/machines`, i.e.
`@/etc/nix/machines`. Prove it on the host instead of trusting either reading:

```sh
mkdir -p /tmp/emptyconf && touch /tmp/emptyconf/nix.conf
NIX_CONF_DIR=/tmp/emptyconf nix config show builders     # expect @/tmp/emptyconf/machines
```

If that prints the machines path, a generation with `distributedBuilds = true` offloads with
no flags; if it prints nothing, the generation needs `nix.settings.builders` set explicitly.

## Fact 2: the `@file` client override needs no root and no switch
A **trusted** user (`trusted-users` contains them) may pass builders per command. Use the
include form, one argument, no shell expansion:

```sh
nix build --impure --builders '@/etc/nix/machines' --option builders-use-substitutes true …
```

- `--builders '@<path>'` makes the **daemon** (root) read the file — the user never reads it.
- Passing the raw machine line as the `--builders` value was observed to hang; the `@file`
  form worked immediately.
- `builders-use-substitutes true` makes the builder fetch inputs from its own substituters
  instead of having the client upload the closure.
- `nixos-rebuild-ng` accepts both flags and forwards them (`--builders BUILDERS`,
  `--option OPTION OPTION`); check with `nixos-rebuild --help`.
- Quote it in fish and bash alike: an unquoted paste that wraps after `--option` gives
  `argument --option: expected 2 arguments` and then runs the value as a command.

## Fact 3: root cannot fetch a user-owned flake checkout from a systemd unit
libgit2 refuses `repository path '…' is not owned by current user` when the process's real
uid owns nothing there. Empirically:

| context | real uid | result |
|---|---|---|
| `sudo nix … /home/da/repo#…` from the user's shell | 1000 | works |
| any systemd unit (root) running the same command | 0 | libgit2 error code 7 |

Fix once, in **root's global** git config — do not chown the repo, do not add repo-local config:

```sh
sudo git config --global --add safe.directory /home/da/.config/dendritic
```

Make it idempotent in any script (`git config --global --get-all safe.directory | grep -qx "$REPO"`).
`git` must be in the *root* path: on NixOS that means `/run/current-system/sw/bin/git`, which
exists when the config repo is managed by the flake; check before relying on it.

## Fact 4: run the long build detached *on the target*, not in an interactive ssh session
Nix cancels an in-progress build when its requesting client disconnects, and an interrupted
build is **not** resumed — the derivation restarts from zero. A `sudo`-ed systemd unit is the
durable client:

```sh
cat > /tmp/rebuild.sh <<'EOF'
#!/bin/sh
exec /run/current-system/sw/bin/nix build --impure --keep-going \
  --builders '@/etc/nix/machines' --option builders-use-substitutes true \
  /home/USER/repo#nixosConfigurations.HOST.config.system.build.toplevel
EOF
chmod +x /tmp/rebuild.sh
sudo systemd-run --unit=HOST-rebuild --collect \
  --property=StandardOutput=file:/tmp/HOST-rebuild.log \
  --property=StandardError=file:/tmp/HOST-rebuild.log \
  --setenv=USER=root --setenv=HOME=/root --setenv=PATH=/run/current-system/sw/bin \
  /bin/sh /tmp/rebuild.sh
```

`--setenv=USER=root` matters when the flake branches on `builtins.getEnv "USER"` (e.g. to
enable root-only hardware paths); systemd sets it anyway, but be explicit.
Watch the log, never the terminal; stop with `systemctl stop`, never Ctrl-C.

## Fact 5: a second client does not protect a build, and a client exit costs the whole run
The build belongs to the client that requested it. With two detached clients asking for the
same derivation, the daemon builds it once, but if the *owning* client exits (earlyoom, a
killed pipe, a closed tmux window) the daemon cancels that build and the surviving client
immediately re-requests it — a fresh sandbox, zero objects, hours gone. Observed: an aarch64
kernel restarted from scratch at the 3.5-hour mark, with the cancelled attempt's drv log
written as a 0-byte file and a new `/nix/var/nix/builds/nix-<pid>-<rand>` directory.

Consequences:
- Run **one** client. Before starting a durable one, stop the strays.
- `pkill` may be absent from the unit's `PATH` (procps is not in the NixOS system profile).
  Kill by reading `/proc`, and report what you stopped:

```sh
killed=0
for d in /proc/[0-9]*; do
  [ -r "$d/cmdline" ] || continue
  cmd=$(tr '\0' ' ' <"$d/cmdline" 2>/dev/null) || continue
  case "$cmd" in *"nix build --impure"*) kill "${d#/proc/}" 2>/dev/null && killed=$((killed+1));; esac
done
echo "stopped $killed detached build client(s)"
```

- Drop `--collect` on the build unit when a watcher must read the outcome: a transient unit
  vanishes on completion, so `systemctl show -p Result` / `-p ExecMainStatus` return empty.
  Keep `--collect` on the watcher unit. Clean up later with `systemctl reset-failed UNIT`,
  and call `reset-failed` on entry too, or a second run dies with "Unit already exists".
- Guard a target-only script against a wrong-host run: the same path often exists on both
  machines. Check `uname -m`, `/home/USER/repo` and `/etc/nix/machines` *before* any action.

## Fact 6: never run `make` inside a live build tree, not even `-n`
GNU make executes recipes that contain `$(MAKE)` even under `--dry-run`, to pass `-n` down to
sub-makes. In a kernel tree that starts real config regeneration and compiler probes in a tree
another build owns; the visible signature is `make[2]: gcc: No such file or directory` from a
command you believed was a dry run. Read the tree with `find` and `stat` only.

## Honest progress for an emulated build
`--print-build-logs` (`-L`) is the single best thing to add to a long client: without it the
log holds one line per derivation (a kernel is one line for hours), the daemon writes its log
file only when the derivation ends (`nix log <drv>` stays empty), and a builder's sandbox is
unreadable as a non-root user. With it you get the real compile stream.

Details that make the stream readable:
- A bare `building '<drv>'` line appears *in addition* to `building '<drv>' on '<builder>'`
  when logs are on. Do not use `grep -v "on 'ssh-ng://"` to detect local builds; use the
  target's load (`uptime` near 0) and `pgrep -c qemu-aarch64` on the builder instead.
- Line counts move in block-buffered bursts, so a short sample is noise in both directions.
  Use 60-second windows.
- pv needs one line per unit and a fixed width (`-w 76`): it otherwise trusts the terminal
  size, which is the tmux window rather than the pane showing it, and the bar wraps and
  floods the scrollback. Drop `-e`: for a guessed total the ETA is a lie, and it is exactly
  the quiet link steps that make it read "12 hours".

Layout of a live sandbox on the builder (root-owned, `drwx------`):

```
/nix/var/nix/builds/nix-<pid>-<rand>/build/source          # unpacked source tree
/nix/var/nix/builds/nix-<pid>-<rand>/build/source/build    # O= output dir: .config,
                                                           # include/config/auto.conf, objects
```

Read-only measurements that work with a cached sudo:

```sh
sudo find <sandbox>/build/source/build -name '*.o' | wc -l       # objects compiled so far
sudo wc -l <sandbox>/build/source/build/modules.order            # exact module count for this config
sudo find <sandbox> \( -name '*.ko' -o -name '*.ko.zst' -o -name '*.ko.xz' \) | wc -l
```

Calibration:
- `make modules` is three passes: compile every `CC [M]` object, one global `modpost`, then
  link the `.ko` files. So the `.ko` count stays 0 for the whole compile stage; a 0 reading
  means "still compiling objects", not "modules barely started". Treat the first `.mod.c` or
  `.ko` appearing as the milestone "object phase over, the end is near".
- `modules.order` is written at the start and lists every module for that config, so it is a
  real denominator without needing another machine's kernel. Counting a *different* build's
  installed modules (`/nix/store/*-modules/lib/modules/*/kernel/**/*.ko*`) is only a sanity
  check; validate such a glob on the host that actually holds that store path.
- `make -n` inside the live sandbox is the tempting way to get "objects remaining" and it must
  not be used (Fact 6). If it is ever needed, source the sandbox `env-vars` first so `CC`,
  `CROSS_COMPILE` and `HOSTCC` point at the builders' wrappers, pass `O=<output dir>`,
  `ARCH=<arch>`, and accept that the count is a snapshot.

## Verification (four separate facts, all cheap)
1. Offload happened: the target's log shows `building '…drv' on 'ssh-ng://user@builder'…`
   (plain `building '…'` with no `on …` is not proof of a local build — see above).
2. Builder received it: `journalctl -u sshd` on the builder shows a fresh
   `Accepted publickey for <builduser>`, and `journalctl -u nix-daemon` shows
   `accepted connection … user <builduser> (trusted)`. A stale timestamp does not count.
3. The builder account works: the committed pubkey must equal the builder's
   `/etc/ssh/authorized_keys.d/<builduser>`, and the pinned base64 host key must equal
   `base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub` on the builder.
4. Emulation really runs: build a foreign-arch one-liner and read its output —
   a *substituted* foreign path proves nothing.
   ```sh
   nix build --impure --print-out-paths --expr \
     'let p = import <nixpkgs> { system = "aarch64-linux"; }; in p.runCommand "emu-proof" {} "uname -m > $out"'
   ```

## Deciding what may cross the link
Derivations are transferable only if the drv path is identical on both hosts:

```sh
nix eval --impure --raw '.#nixosConfigurations.HOST.config.boot.kernelPackages.kernel.drvPath'
```

Compare against the client's drv. Re-check after any `git pull`: a bump of the kernel input
changes the drv and silently wastes a finished remote build. Hardware-derived derivations
(dirs embedding vendor firmware, initrd, toplevel) never match across machines — those stay
local, and the final `nixos-rebuild switch` must run on the target. A builder that lacks an
advertised feature silently keeps work local: compare the drv's `requiredSystemFeatures`
(`nix derivation show <drv>`) with the machine line's feature list.

## Order of operations that worked
1. Confirm the target's own limits (`max-jobs`, `cores`) and that the heavy drv is uncached —
   probe `https://<cache>/<out-hash>.narinfo` for 404 before blaming substitution.
2. Prove the link with a tiny `--max-jobs 0` build through the builder.
3. Start the real build as one durable unit (Fact 4), with `--print-build-logs`, and a second
   unit that waits for it and writes a report plus a sentinel file.
4. Poll the sentinel from the agent side, so an AFK user does not have to watch.
5. Only then switch, which installs the machines file declaratively so the next bump needs
   no flags. Root the new generation before any GC can run: a `--no-link` build leaves the
   copied closure unrooted until the switch creates the generation, and a weekly
   `nix.gc.automatic` timer would otherwise collect it.
