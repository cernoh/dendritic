---
name: dendritic-asahi-cross-build
description: "Prebuild the ASAHI (aarch64) host on NIXPC (x86_64) and move the results to the Mac: the built distributed-build link (base64 publicHostKey, ssh-ng + trusted-users, load-bearing big-parallel feature, tailnet IP address), the binfmt/qemu check, the placeholder-eval boundary, the nix copy trust route, and the pre-switch link proof. Use when asked to build ASAHI from NIXPC, to change the remote-builder link, or when a remote aarch64 build stays local."
---

# Cross-building ASAHI from NIXPC

Answer shape: **build yes, ship-a-system no**. Packages are transferable; the toplevel is not.

## 0. The distributed-build link exists (issue #209, PR #212)

`modules/system/distributed-builds/` holds both halves, already wired into the hosts:

- `builder.nix` → `flake.nixosModules.remoteBuilder`, imported by `modules/hosts/NIXPC/default.nix`
- `client.nix` → `flake.nixosModules.distributedBuilds`, imported by `modules/hosts/ASAHI/default.nix`
- `_link.nix` + `remotebuild.pub` — account, key path, tailnet address, host key in one place

Rendered client line (`/etc/nix/machines` on ASAHI):

```
ssh-ng://remotebuild@100.121.170.108 aarch64-linux /root/.ssh/remotebuild 8 1 big-parallel - <base64 host key>
```

### Facts that cost time (verified 2026-09-16)

1. **`publicHostKey` takes base64 of the whole key line, computed from the file bytes.** Nix tokenizes the machines file on whitespace and `ensureBase64` rejects anything else (`libstore/machines.cc`); `ssh.cc parsePublicHostKey` base64-decodes it into a known_hosts entry. Compute it as `base64 -w0 /etc/ssh/ssh_host_ed25519_key.pub` — read the file, never retype the key in a shell string, because a stray trailing space, `\n`, or literal `\n` two-character sequence travels into the pinned entry. Verify the committed value by decoding it and diffing against the file.
2. **`supportedFeatures = [ "big-parallel" ]` is load-bearing.** `linux-asahi` carries `requiredSystemFeatures = [ "big-parallel" ]`. A builder that does not advertise the feature gets no bootchain work and the kernel stays on the Mac. Leave `kvm` and `nixos-test` out: `/dev/kvm` cannot accelerate an aarch64 guest on x86_64.
3. **`protocol = "ssh-ng"` is not the option default** (`nix.buildMachines.*.protocol` defaults to `"ssh"`). ssh-ng runs `nix-daemon --stdio` on the builder as the login account (`ssh-store.hh`, `remoteProgram`), which is why that account must sit in the builder's `nix.settings.trusted-users` — the entry is what lets the daemon accept unsigned store imports. The legacy protocol wants store-group access instead.
4. **The remote account needs no home.** `isSystemUser = true` gives `/var/empty`, and sshd reads keys from `/etc/ssh/authorized_keys.d/%u`. A non-interactive ssh session still gets `/run/current-system/sw/bin` on PATH through pam_env (`/etc/pam/environment`), so `nix-daemon` resolves with no extra work.
5. **The private key cannot come from the store.** Install it once as root on ASAHI: `sudo install -o root -g root -m 600 <key> /root/.ssh/remotebuild`. The repo is public, so only `remotebuild.pub` is committed — and the public key goes in as a *key file* (`openssh.authorizedKeys.keyFiles`), never as key text in a Nix string, which would land world-readable in `/nix/store`. Move the key with `scp -O`: `da@ASAHI` authenticates through Tailscale SSH, which has no SFTP subsystem, so plain `scp` fails.
6. **Address the builder by its tailnet IPv4 address, `100.121.170.108`** (ASAHI is 100.124.99.107). Names do not work here: both hosts resolve through the unbound instance of `system/network` (`nameserver 127.0.0.1` in `/etc/resolv.conf`), and that resolver does not serve the tailnet zone. Verified 2026-09-16 with `getent hosts`: `nixpc` and `nixpc.tail49d78b.ts.net` fail on NIXPC *and* on ASAHI, while `nc -vz 100.121.170.108 22` from ASAHI succeeds. `tailscale ping nixpc` still works, because tailscale looks the peer up itself — it proves the tailnet, not the resolver.
7. **`maxJobs` and the builder's `cores` multiply.** NIXPC leaves `cores = 0` (every job may use all 16 threads), so `maxJobs = 8` permits 8 × 16 threads while one `linux-asahi` build already saturates the 3700X. Treat 8 as a starting value and tune it after the first kernel build; the desktop pays the oversubscription directly.
8. **Do not `builtins.getFlake` a checkout while an ssh control socket sits in it.** An omp ssh call leaves `modules/features/omp/home/ssh-control/<hash>.sock`, and a path fetch of a tree that contains a socket fails with `file '…sock' has an unsupported type`. The same happens on the Mac through `modules/features/omp/home/run/daemons/*/broker.sock`. Eval with `import <nixpkgs>`, which reads the NIX_PATH store path and never touches the tree, or delete the stale socket first. `git status` stays clean, because those paths are gitignored.

### Verification recipe

```sh
nix run .#verify                                     # parse, eval-pure, hardware, fmt
nix eval --impure --raw '.#nixosConfigurations.ASAHI.config.environment.etc."nix/machines".text'
nixos-rebuild build --impure --flake .#NIXPC         # proves the system builds, not only evaluates
# `environment.etc."nix/nix.conf".text` is null: the entry is a symlink to a store path
CONF=$(nix build --impure --no-link --print-out-paths '.#nixosConfigurations.NIXPC.config.environment.etc."nix/nix.conf".source')
nix eval --impure --raw --expr "builtins.readFile \"$CONF\"" | grep trusted-users
# same trick for the builder key: ...etc."ssh/authorized_keys.d/remotebuild".source
```

Proof of the link before any ASAHI switch (no root, no machines file), as user `da` on the Mac:

```sh
STORE="ssh-ng://remotebuild@100.121.170.108?ssh-key=/home/da/.remotebuild&base64-ssh-public-host-key=<base64>"
nix store info --store "$STORE" | tail -1            # expect: Trusted: 1
DRV=$(nix eval --impure --raw --expr 'let p = import <nixpkgs> { system = "aarch64-linux"; };
  in (p.runCommand "link-proof" { } "uname -m > $out").drvPath')
nix copy --to "$STORE" "$DRV"                        # drv travels to NIXPC
nix-store --store "$STORE" --realise "$DRV"          # NIXPC builds it there
nix path-info <out>                                  # must be INVALID locally
nix store cat --store "$STORE" <out>                 # expect: aarch64
```

Observed trap: `nix build --store ssh-ng://… <drv>` exits 0 and prints the drv without building anything, so it proves nothing. Use `nix copy --to` followed by `nix-store --store … --realise`. The absence of the output from the local store is the proof that NIXPC built it, and a fast build is normal: NIXPC substitutes the aarch64 stdenv from its own caches, then runs one emulated command.

After both switches, the daemon path (a user-level run is enough, the daemon owns `/etc/nix/machines`):

```sh
nix build --max-jobs 0 --no-link --impure --expr '(import <nixpkgs> {}).writeText "t" (toString builtins.currentTime)'
```

Two different silent outcomes on the client side, and they need different proofs:

- **No matching machine** (wrong system, missing feature) → the work silently stays local. Nix reports nothing, so cross-check the feature list against the drv.
- **A listed machine that is unreachable** → no fallback; the jobs sent to it fail. A dead tailnet breaks builds instead of degrading them, so check that the log names `ssh-ng://remotebuild@100.121.170.108` before claiming the link works.

## 1. Confirm NIXPC can run aarch64

`modules/hosts/NIXPC/nixpcConfiguration.nix` sets `boot.binfmt.emulatedSystems = [ "aarch64-linux" ]`, which populates `nix.settings.extra-platforms`. Verify on the running machine:

```sh
nix config show extra-platforms    # expect: aarch64-linux i686-linux
/nix/store/<...>-hello-*/bin/hello # an aarch64 hello must print Hello, world!
```

A *substituted* aarch64 path (as `nix build nixpkgs#legacyPackages.aarch64-linux.hello` gives) proves nothing about emulation — execute the binary.

## 2. Eval off-machine is placeholder mode (by design)

```sh
nix eval --impure --raw '.#nixosConfigurations.ASAHI.config.system.build.toplevel.drvPath'
# warning: hardwareFromMachine aarch64-linux: ... placeholder root filesystem
```

Proof the artifact is not deployable:

```sh
nix eval --impure --json '.#nixosConfigurations.ASAHI.config.fileSystems'
# "/" device = /dev/disk/by-label/nixos  (placeholder, not the real by-uuid)
```

Also `asahiConfiguration.nix`: `onMacAsRoot = evalSystem == "aarch64-linux" && getEnv "USER" == "root"` → off-machine `hardware.asahi.peripheralFirmwareDirectory = null`, `extractPeripheralFirmware = false`. The real toplevel (real root fs, `/boot/vendorfw`) can only be built by the Mac with `--impure`; `switch-to-configuration` there is what installs U-Boot/m1n1 onto the ESP.

## 3. Size the plan before committing

```sh
nix build --dry-run --impure '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
```

Reference run (2026-09, linux-asahi 7.1.13): **802 derivations to build**, 2362 paths to fetch (6.9 GiB → 21.0 GiB unpacked). The bootchain sits in the *build* set — `linux-asahi`, `-modules`, `-modules-shrunk`, `initrd-linux-asahi`, `installkernel`, `uboot-apple_m1_defconfig-*-asahi` — while `m1n1` substitutes. That matches `nix-settings.nix` / `hosts/AGENTS.md` (issue #73: no upstream cache for the bootchain).

Note the link load: 8 emulated jobs in the built config, and the kernel itself is `big-parallel`, so it takes the whole builder slot. Do not use `time` or `tail` on this command; the output is large and the harness elides the middle.

## 4. Transfer

Route A — prebuild + copy, no config change on the Mac:

```sh
nix build --impure '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
nix copy --impure --to ssh-ng://da@<mac> '.#nixosConfigurations.ASAHI.config.system.build.toplevel'
# then on the Mac
sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI
```

Signatures are a non-issue: `nixSettings` sets `trusted-users = [ "root" config.dendritic.userName ]`, and `dendritic.userName = "da"` on ASAHI (`asahiConfiguration.nix`), so pushing as `da` adds unsigned paths. Note the `trusted-users` list renders with `root` twice (`nixpkgs` default plus this repo's entry) — harmless.

Route B — the built remote builder (section 0): ASAHI schedules its aarch64 derivations on NIXPC and copies outputs back. Payoff: `asahiConfiguration.nix` hard-caps the Mac to `max-jobs = 1; cores = 1` for earlyoom/OOM reasons, while NIXPC runs 8 emulated jobs.

## 5. Honest caveats

- Only hardware-independent paths coincide. Kernel config is not derived from `hardware-configuration.nix`, so `linux-asahi` should match — prove it by running the same `--dry-run` on the Mac and checking those entries left the build list.
- Emulated kernel + U-Boot is hours, not minutes, even with the link.
- qemu-user breaks individual derivations occasionally; some of the many bootchain derivations may fall back to the Mac.
- The link depends on `tailscaled` on both hosts and a completed `tailscale up`. Losing the tailnet sends the work back to the Mac without an error.
- Neither route changes the deploy boundary: the final `switch --impure` must run on the Mac, followed by the reboot signalled by `/run/reboot-required` (issue #72) and `modules/hosts/ASAHI/RESCUE.md` for rollback.
