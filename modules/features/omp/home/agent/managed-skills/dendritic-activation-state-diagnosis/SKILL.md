---
name: dendritic-activation-state-diagnosis
description: "Diagnose \"the feature I merged is not running\" on a dendritic host without debugging units: check the source checkout HEAD against origin/main (a merge deploys nothing until the checkout pulls), compare /run/booted-system with /run/current-system, inspect the generation store path for the unit AND status whether /run/current-system actually contains it, test sudo -n, and pre-build plus inspect the toplevel closure before the user switches."
---

Apply when the user says a merged feature is not live ("I rebooted, test if it runs"). Order matters: the source tree is the most common cause, and it is invisible from `systemctl`.

Verified against cernoh/dendritic on NIXPC, 2026-09-16, after three merged
herdr-web PRs appeared absent after a reboot.

## 1. The source checkout (do this first)

A dendritic host deploys from a working checkout, usually
`~/.config/dendritic`. Merged commits on `origin/main` reach the machine only
after that checkout pulls them.

```bash
cd ~/.config/dendritic
git log -1 --format='%h %s'          # local HEAD
git log origin/main -1 --format='%h %s'
ls modules/features/<name>/          # does the feature exist here at all?
```

If HEAD is behind, the feature never existed on the machine, and no unit
debugging will help. Before pulling in a shared checkout:

```bash
git fetch origin
git diff --name-only HEAD..origin/main   # incoming files
git diff --name-only                     # other agents' local edits
```

No overlap means `git pull --ff-only` is safe and leaves their edits and
untracked work untouched. Watch for `git add -N` intent-to-add entries, which
block a pull (see the git-intent-to-add-pull-blocker skill).

## 2. Booted vs current generation

```bash
readlink -f /run/booted-system /run/current-system
tr ' ' '\n' < /proc/cmdline | grep init=
cat /proc/uptime
ls -l --time-style=full-iso /nix/var/nix/profiles/ | grep system- | tail -3
```

`/run/booted-system` is what the kernel actually booted. `/run/current-system`
can already point at a newer generation that the running services do not come
from. A switch that was built from a stale checkout updates the profile but
still has no feature in it. Compare the uptime against the generation
timestamps to see which came first.

## 3. Prove the unit state from the store, not from systemd

```bash
S=$(readlink -f /run/current-system)
ls $S/etc/systemd/system/<unit>.service                       # system unit
ls $S/etc/systemd/system/multi-user.target.wants/ | grep <unit>
systemctl list-unit-files | grep <unit>; systemctl --user list-unit-files | grep <unit>
```

A home-manager user unit is not in `/run/current-system`. It lands in the HM
generation:

```bash
HM=$(nix eval --impure --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.activationPackage)
ls -l "$HM/home-files/.config/systemd/user/<unit>.service"
ls -l "$HM/home-files/.config/systemd/user/default.target.wants/" | grep <unit>
nix eval --impure --json .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.systemd.user.startServices
```

`startServices = true` means HM activation installs and starts new user units
on the switch, so no reboot and no manual start is needed.

## 4. Can this session even activate?

```bash
sudo -n true || echo "sudo needs a password: activation is the user's step"
```

Usually it does, so hand over one command and pre-build the closure instead:

```bash
nix build --impure --no-link --print-out-paths .#nixosConfigurations.<HOST>.config.system.build.toplevel
```

Then prove the units are inside that closure before the user switches, by
listing `$out/etc/systemd/system/…` and `$out/etc/systemd/system/*.target.wants/`.
That converts "run the rebuild and hope" into "activation only, nothing to
build", and it separates build failures from activation failures.

## Report shape

State what is running, what is built, what the user must run, and the
post-switch checks (unit status, the feature's own endpoint, logs). Do not
report a feature as fixed because a build exists; a build is not an activation.
