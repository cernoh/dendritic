# Computer-use toolchain: observe and drive a Wayland session from the shell.
# This covers agent GUI work (screenshot plus vision loops, scripted input) as
# well as manual screen capture (issue #146).
#
# One concern per feature dir. NixOS-scoped: every process in the session can
# use these binaries, and both hosts run a wlroots-based Wayland desktop
# (NIXPC mango, ASAHI niri).
#
# Included:
#   grim          wlroots screencopy — whole-layout, per-output, and region PNG
#   slurp         region picker for `grim -g "$(slurp)"`
#   wayland-utils wayland-info: which protocols the compositor really exposes
#   wlr-randr     output geometry and EDID ground truth
#   wlrctl        pointer injection plus foreign-toplevel control
#   wtype         keyboard injection via zwp_virtual_keyboard_manager_v1
#
# Deliberately absent:
#   - wl-clipboard: NIXPC gets wl-clipboard-rs through `mango`, ASAHI gets the
#     C wl-clipboard through the `clipboard` HM feature. A third copy here
#     would collide on wl-copy/wl-paste inside the system profile.
#   - ydotool: it needs write access to /dev/uinput, which is root-only here.
#   - xdotool / wmctrl: X11 only, useless under Wayland.
#
# `mango` also installs grim and slurp for its screenshot bindings. The
# duplicate is the same derivation, so buildEnv de-duplicates by store path.
#
# Also owns the pi-computer-use runtime: the npm extension ships a
# generic-glibc `cua-driver` ELF that NixOS cannot exec (no loader). See
# home.activation.cuaDriver below and computer-use/AGENTS.md.
#
# Opt in from a host: imports = [ self.nixosModules.computerUse ];
# attrs/desktop imports it, so both hosts get it.
{ inputs, ... }:
{
  flake.nixosModules.computerUse =
    {
      pkgs,
      config,
      ...
    }:
    {
      environment.systemPackages = with pkgs; [
        grim
        slurp
        wayland-utils
        wlr-randr
        wlrctl
        wtype
        # Only needed by home.activation.cuaDriver below, which patchelfs the
        # npm cua-driver at activation.
        patchelf
      ];

      # pi-computer-use (npm:@amaster.ai/pi-computer-use) needs a runnable
      # cua-driver. The npm binary is a generic-glibc ELF, so on NixOS it dies
      # with "could not start dynamically linked executable". Activation copies
      # its bin dir to ~/.local/share/cua-driver and rewrites INTERP + RPATH to
      # the nixpkgs glibc loader and the X11 libs it links (libX11, libXi,
      # libxkbcommon). Copy-and-patchelf, not a bare wrapper script: the driver
      # re-executes /proc/self/exe for `status`/`stop`, which a loader-based
      # wrapper breaks (the child would exec ld.so with the subcommand as a
      # library name). Siblings stay next to it because it resolves
      # cua-cursor-theme and wayland-helper relative to its own path.
      #
      # ~/.pi/agent/settings.json (tracked in features/pi-coding-agent/home)
      # points pi at the patched copy:
      #   "pi-computer-use": { "mode": "path",
      #     "binaryPath": "${HOME}/.local/share/cuda-driver/cua-driver" }
      home-manager.users.${config.dendritic.userName} =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          hmDag = inputs.home-manager.lib.hm.dag;
          home = config.home.homeDirectory;
          src = "${home}/.pi/agent/npm/node_modules/@amaster.ai/pi-computer-use-cua-driver-linux-x64/bin";
          dst = "${home}/.local/share/cua-driver";
          patchelf = "${pkgs.patchelf}/bin/patchelf";
          interp = "${pkgs.glibc}/lib/ld-linux-x86-64.so.2";
          rpath = lib.makeSearchPath "lib" [
            pkgs.glibc
            pkgs.gcc.cc.lib
            pkgs.libX11
            pkgs.libXi
            pkgs.libxkbcommon
            pkgs.libXext
            pkgs.libXfixes
            pkgs.libXrender
            pkgs.libxcb
            pkgs.libXau
            pkgs.libXdmcp
            pkgs.libbsd
            pkgs.zlib
          ];
        in
        {
          # Plain shell: Home Manager writes activation entries verbatim, so
          # `then`/`else`/`fi` must sit on their own lines (a `run ` prefix per
          # line would break the `bash -n` syntax check).
          home.activation.cuaDriver = hmDag.entryAfter [ "writeBoundary" ] ''
            src='${src}'
            dst='${dst}'
            # npm has no aarch64 driver package; hosts without it skip quietly
            # instead of failing activation.
            if [ ! -x "$src/cua-driver" ]; then
              echo "computer-use: no npm cua-driver under $src, skipping" >&2
            # Re-patch when the copy is missing or its INTERP is the stock
            # /lib64/ld-linux-x86-64.so.2 (fresh npm install, or
            # `cua-driver update --apply` replacing the patched copy).
            elif [ ! -x "$dst/cua-driver" ] ||
              [ "$(${patchelf} --print-interpreter "$dst/cua-driver" 2>/dev/null)" != '${interp}' ]
            then
              rm -rf "$dst"
              mkdir -p "$dst"
              cp -r "$src/." "$dst/"
              chmod -R u+w "$dst"
              for f in "$dst"/*; do
                [ -f "$f" ] || continue
                ${patchelf} --set-interpreter '${interp}' \
                  --force-rpath --set-rpath '${rpath}' "$f" 2>/dev/null || true
              done
            fi
          '';
        };
    };
}
