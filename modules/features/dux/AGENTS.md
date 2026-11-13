# Dux suite (`features/dux`)

## Purpose

The whole Dux (Dank) shell suite — the replacement for `noctalia` +
`noctaliaGreeter` — in one directory. Four upstream forks, four exported
modules, one bundle both hosts import:

| File | Upstream input | Option it enables | Half |
|---|---|---|---|
| `shell.nix` | `inputs.dms` (dux-shell) | `programs.dank-material-shell` | both |
| `greeter.nix` | `inputs.dms-greeter` | `programs.dms-greeter` | NixOS |
| `search.nix` | `inputs.dsearch` (dux-search) | `programs.dsearch` | HM |
| `calendar.nix` | `inputs.dcalendar` | `programs.dank-calendar` | HM |
| `default.nix` | — | bundle `dux` + the shell's mango binds | both |

## Ownership

`default.nix` decides which file lands on which half and is the only module a
host imports. `shell.nix` owns the shell's configuration: one `shared` attrset
applied to both halves, so NixPC and ASAHI cannot drift. `greeter.nix` owns
greetd. Nothing here names a colour — see `Local Contracts`.

## Local Contracts

- **The option names are not the feature names.** `dms` is
  `programs.dank-material-shell`; the retired `programs.dms-shell` fails the
  eval with ``The option `programs.dms-shell' does not exist``. Also
  `programs.dms-greeter`, `programs.dsearch`, `programs.dank-calendar`.
  Defining an option without importing the upstream module that declares it
  fails identically, so every file here is `imports = [
  inputs.<input>.<class>Modules.default ]` **plus** settings.
- **Upstream owns the options and the units; this repo only picks the half.**
  `dms.service` is defined by upstream in *both* halves, so `systemd.enable` is
  set on the HM half only — `shell.nix`'s NixOS half leaves it at the default
  (off). `dms-greeter` is NixOS-only (it runs before any session) and needs
  `services.greetd.settings.default_session.user`, which it reads but never
  sets. `dsearch` publishes no NixOS module at all. `dank-calendar` defines
  `dcal.service` in both halves; the HM one is kept.
- **Never declare `settings`, `clipboardSettings` or `session`.** Upstream
  renders each as a store symlink under `~/.config/dms/`, and the shell rewrites
  those files from its own UI. Declaring them freezes the live `settings.json`
  (bar layout, widgets, `currentThemeName`) at build time and breaks in-app
  persistence. The shell's runtime settings are deliberately not nix-managed.
- **Leave `package` at the upstream default.** `mkModuleWithDmsPkgs` builds the
  shell from the *consumer's* pkgs, so it shares one nixpkgs eval with the
  quickshell it runs; `inputs.dms.packages.<system>.default` would build against
  dux-shell's locked nixpkgs — a second Qt tree, for an upstream with no binary
  cache.
- **The suite contributes the shell's compositor keys, not `features/mango`.**
  `default.nix` adds four `dendritic.mango.extraBinds` entries (`SUPER,D`
  launcher, `SUPER+SHIFT,S` region, `CTRL+Print` focused output, `ALT,Print`
  window screenshot) as absolute `${lib.getExe
  config.programs.dank-material-shell.package}` invocations, because a
  `spawn_shell` bind inherits the session PATH while the shell is a per-user
  package. Keys are exclusive: a duplicate fails `mango -c -p`, i.e. the build.
  Noctalia's `cernoh/terminal` dropdown had no DMS equivalent (DMS's only
  `scratchpad` IPC target is Hyprland-gated), so `SUPER+SHIFT+T` was dropped
  rather than remapped.
- **Theming is runtime, not build-time — the shell owns GTK, Qt, MangoWM and the
  terminal.** `enableDynamicTheming` only puts `matugen` on PATH; the shell's
  `matugenTemplate*` settings (all default on except Neovim) then write *include*
  files: `~/.config/gtk-{3,4}.0/dank-colors.css` (and `gtk.css` itself, which
  `gtk.sh` creates because nothing else owns it here), `~/.config/mango/dms/colors.conf`,
  `~/.config/ghostty/themes/dankcolors`, `~/.config/qt6ct/colors/matugen.conf`,
  `~/.config/qtengine/config.json`. A wallpaper change recolours all of them
  without a rebuild. The consumers are wired deliberately, and each has a
  constraint worth knowing before touching it:
  - `features/stylix` keeps `targets.gtk` and `targets.qt` **off**. A stylix
    `gtk.css` is a store symlink DMS's `gtk.sh` refuses to inject into, and
    stylix's NixOS-side Kvantum sets `QT_STYLE_OVERRIDE=kvantum`, which beats
    the qt6ct config DMS writes.
  - `features/mango` appends the include to the end of the rendered config —
    `source_optional = /home/<user>/.config/mango/dms/colors.conf` — rather than
    writing it into the settings attrset, because `toMango` sorts keys and a
    `*_color` key sorting after `source_optional` (`urgent_color`) would beat the
    include. `source_optional` because the build-time `mango -c -p` gate runs in
    the sandbox where that path cannot exist.
  - `features/ghostty` names `--theme=dankcolors` and passes **no** explicit
    colour flags: an explicit colour key always beats a `theme` in any order, so
    keeping the old `--background`/`--palette` flags would pin the terminal.
  - `features/nvf`, `zellij`, `tmux` and `omp` stay on `self.scheme`. Neovim's
    template exists but defaults off, and turning it on needs a `settings` key —
    which this feature must not declare (previous bullet). DMS has no template
    for the other three.

## Work Guidance

- Add a new dux tool as a sibling file plus an `inputs.<name>` in `flake.nix`;
  name the exported module after the *feature*, and record its option name in
  the table above.
- Keep `shared` in `shell.nix` keyed by upstream's own option names so a dux
  bump is a diff against upstream's `distro/nix/options.nix`, not a translation.
- Verify the fork against its source: the locked dux-shell tree in the store
  carries `distro/nix/options.nix`, `home.nix` and `nixos.nix` — read them
  before assuming an option still exists.

## Verification

- `nix-instantiate --parse modules/features/dux/*.nix`
- `nix eval .#nixosConfigurations.ASAHI.config.home-manager.users.da.programs.dank-material-shell --impure`
  and `.#nixosConfigurations.NIXPC.config.home-manager.users.davr.programs.dank-material-shell --impure`
  — the HM user name differs per host; the two must report identical values for
  the `enable*` flags and `systemd.restartIfChanged`. That is the "same on both
  hosts" contract.
- `nix eval .#nixosConfigurations.<HOST>.config.programs.dank-material-shell --impure`
  must report `systemd.enable = false` (HM owns the unit).
- `nix eval .#nixosConfigurations.<HOST>.config.programs.dms-greeter --impure`
