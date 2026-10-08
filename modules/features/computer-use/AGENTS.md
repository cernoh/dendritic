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

## Work Guidance

- pi reads this config at session start, so a changed `binaryPath` needs a pi
  reload before `computer_use_connect` sees it.
- Known runtime limit, not a packaging bug: `get_desktop_state` capture goes
  through X11 `GetImage`, which XWayland refuses. `grim` remains the working
  capture path on both hosts.

## Verification

- `nix eval .#nixosConfigurations.NIXPC.config.systemd.user.startServices` is
  irrelevant here; the real check is activation plus the driver itself:

  ```bash
  patchelf --print-interpreter ~/.local/share/cuda-driver/cua-driver   # nix loader
  ~/.local/share/cuda-driver/cua-driver doctor
  ~/.local/share/cuda-driver/cua-driver status --socket <sock>   # re-exec path
  ```

- Repo ladder: `nix-instantiate --parse modules/features/computer-use/default.nix`
  then `nix run .#verify`.

## Child DOX Index

- None. This module is one file plus this doc.