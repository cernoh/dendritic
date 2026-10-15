# computer-use

## Purpose

Everything an agent needs to see and drive the live desktop session:

- wlroots shell tools (`grim`, `slurp`, `wlrctl`, `wtype`, `wayland-utils`,
  `wlr-randr`) for scripted capture and input.
- The `pi-computer-use` runtime: the npm extension ships a generic-glibc
  `cua-driver` ELF that NixOS cannot exec, so activation produces a patched
  copy.

## Ownership

- `flake.nixosModules.computerUse` — the wlroots tools plus
  `home.activation.cuaDriver`. `attrs/desktop` imports it, so both hosts get it.
- The pi settings that point at the patched driver live in
  `modules/features/pi-coding-agent/home/agent/settings.json` (tracked), under
  `"pi-computer-use"`. That is the one cross-module coupling here: the module
  owns the binary, the pi feature owns the file that names it.

## Local Contracts

- `cua-driver` is patched by **copy + `patchelf`**, never by a loader wrapper
  script. The driver re-executes `/proc/self/exe` for `status` and `stop`; under
  a wrapper (`steam-run`, `ld.so <libpath> <binary>`) `/proc/self/exe` is the
  loader, so the child execs `ld.so` with the subcommand as a library name and
  dies with `error while loading shared libraries: stop`. `steam-run` has a
  second, independent failure: it `--tmpfs /tmp`, so the daemon socket the pi
  client creates in `TMPDIR` is invisible across instances.
- `INTERP` goes to `pkgs.glibc`; `RPATH` covers `DT_NEEDED` beyond glibc:
  `libX11`, `libXi`, `libxkbcommon` and their deps (`libxcb`, `libXau`,
  `libXdmcp`, `libXext`, `libXfixes`, `libXrender`, `libbsd`, `zlib`) plus
  `gcc.cc.lib` for `libgcc_s`. Recompute with
  `patchelf --print-needed <npm cua-driver>` when the npm package updates.
- Patch the whole `bin` dir, not just the driver: it resolves
  `cua-cursor-theme` and `wayland-helper` relative to its own path.
- Activation is idempotent and cheap: it re-patches only when the copy is
  missing or `patchelf --print-interpreter` is not the nix loader. That also
  covers a self-update (`cua-driver update --apply`) dropping a pristine binary
  back in — otherwise the next `home-manager switch` repairs it.
- A host without the npm driver (no aarch64 package) skips with a warning; it
  must not fail activation.
- The AT-SPI2 accessibility bus is on with this module, always. The driver
  inspects the desktop through `org.a11y.Bus`; with it unowned the driver
  reports `ax_capability` down and every element-tree tool (`get_window_state`,
  element `click`/`type`/`set_value`) fails even on a live session.
  `services.gnome.at-spi2-core.enable = true` starts the bus (dbus + a systemd
  user unit) and — critically — stops that module's default `NO_AT_BRIDGE=1` /
  `GTK_A11Y=none` session overrides, which are what actually silence the GTK
  bridge. `programs.dconf` then flips `org.gnome.desktop.interface
  toolkit-accessibility` (the switch the driver's own probe names) so GTK apps
  publish their tree. Host-agnostic: AT-SPI2 rides the session D-Bus on both
  mango and niri, so there is no per-host option. `programs.dconf.enable` may
  also be set by another feature (e.g. `easyeffects`); the two merge, only the
  `profiles.user` database is owned here.

## Work Guidance

- pi reads this config at session start, so a changed `binaryPath` needs a pi
  reload before `computer_use_connect` sees it.
- The daemon inherits **pi's environment verbatim**: the extension spawns
  `cua-driver serve --socket …` with `env: process.env`, and its
  `pi-computer-use` config block has no env hook. So a pi launched outside the
  graphical session (no `WAYLAND_DISPLAY` / `DISPLAY`) produces a driver that
  cannot reach the compositor — `list_windows`, `get_accessibility_tree`, and
  clipboard all fail with "$DISPLAY variable not set" while `list_apps` (reads
  `/proc`) still works. That is a **pi-launch-environment concern** (the
  mango/niri/pi features own the session env), not something this module can
  fix — the fix is to launch pi from a desktop terminal so it inherits
  `WAYLAND_DISPLAY`/`DISPLAY` (`wayland-0` / `:0` on NIXPC).
- Known runtime limit, not a packaging bug: `get_desktop_state` capture goes
  through X11 `GetImage`, which XWayland refuses. `grim` remains the working
  capture path on both hosts. The a11y bus above is what the element-tree
  tools need; screen capture is the remaining gap.

## Verification

- `nix eval .#nixosConfigurations.NIXPC.config.systemd.user.startServices` is
  irrelevant here; the real check is activation plus the driver itself:

  ```bash
  patchelf --print-interpreter ~/.local/share/cuda-driver/cua-driver   # nix loader
  ~/.local/share/cuda-driver/cua-driver doctor
  ~/.local/share/cuda-driver/cua-driver status --socket <sock>   # re-exec path
  ```

- The a11y bus (this module's other half) verifies two ways — the option
  resolves, and the bus actually has an owner in the live session:

  ```bash
  nix eval .#nixosConfigurations.NIXPC.config.services.gnome.at-spi2-core.enable --impure   # true
  busctl --user list | grep a11y            # org.a11y.Bus + a11y registryd units
  gsettings get org.gnome.desktop.interface toolkit-accessibility   # true
  ```

  `busctl` and `gsettings` run inside the graphical session (they need the
  session bus / the dconf DB the module writes).

- Repo ladder: `nix-instantiate --parse modules/features/computer-use/default.nix`
  then `nix run .#verify`.

## Child DOX Index

- None. This module is one file plus this doc.