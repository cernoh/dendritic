# The LuaTools stack: Lumen (a static Lua backend) plus its LuaTools plugin,
# laid out under ~/.local/share/Lumen for slsteam-moon to drive.
#
# Both are copied out of the store on activation instead of being linked, because
# they write at runtime: Lumen keeps its config, fetched manifest packs and the
# cef_port file it publishes, and the plugin keeps its state under backend/.
{
  lumen,
  luatools-moon,
}:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nix-crab.luatools;

  lumenDir = "${config.xdg.dataHome}/Lumen";
  stampDir = "${lumenDir}/.nix-crab";

  lumenDist = pkgs.runCommandLocal "lumen-dist" { } ''
    install -d "$out"
    ${lib.getExe pkgs.unzip} -qo ${lumen}/dist/lumen-linux.zip -d "$out"
    chmod +x "$out/lumen"
  '';

  # The plugin repo ships the canonical plugin/ source tree rather than a built
  # dist, so package it the way its own scripts/build.sh does — minus the index
  # refresh, so the committed ryuu_index.json stays the one that was reviewed.
  pluginDist = pkgs.runCommandLocal "luatools-moon-dist" { } ''
    install -d "$out"
    cp -r ${luatools-moon}/plugin/. "$out/"
    rm -rf "$out/backend/data" "$out/backend/temp_dl"
    rm -f "$out/backend/lua_runtime.log" \
      "$out/backend/loadedappids.txt" \
      "$out/backend/appidlogs.txt"
    chmod +x "$out/backend/scripts/"*.sh "$out/backend/bin/7zz"
  '';

  # Lumen's prebuilt binary is a plain ELF that needs an FHS sandbox on NixOS,
  # so the shipped `lumen` is replaced by this launcher and the binary becomes
  # lumen.bin. Two things are load-bearing:
  #   * `cd` first — lumen.bin resolves lua/ relative to the working directory;
  #   * the LD_AUDIT/LD_PRELOAD unset happens INSIDE steam-run, because those
  #     carry slsteam-moon's 32-bit hooks and pkgs.steam's extraEnv lands in the
  #     FHS rootfs /etc/profile, which steam-run sources. Unsetting them outside
  #     the sandbox is a no-op, and every 64-bit backend script then dies with
  #     "wrong ELF class".
  # LUMEN_BACKEND_DIR is how Lumen discovers the plugin backend: boot.lua only
  # loads it when the variable is set, and without it every plugin call fails
  # with "unknown method".
  launcher = pkgs.writeShellScript "lumen" ''
    cd "$(dirname "$0")" || exit 1
    export LUMEN_BACKEND_DIR="$PWD/luatools/backend"
    export LUMEN_LUA_DIR="$PWD/lua"
    exec steam-run env -u LD_AUDIT -u LD_PRELOAD ./lumen.bin "$@"
  '';

  # Lumen has no single-instance guard, so a second launch (a steam:// link from
  # the browser, a second desktop-entry click) would stack another sidecar onto
  # the same CEF target. pgrep-guarded; Lumen polls for the port itself
  # (lua/cefport.lua), so nothing has to be synchronised here.
  steamWrapper = pkgs.writeShellScriptBin "steam" ''
    real_steam=""
    old_ifs=$IFS
    IFS=:
    for directory in $PATH; do
      [ -n "$directory" ] || continue
      candidate="$directory/steam"
      [ -x "$candidate" ] || continue
      # -ef also skips symlinks that resolve to this very wrapper.
      [ "$candidate" -ef "$0" ] && continue
      real_steam=$candidate
      break
    done
    IFS=$old_ifs

    if [ -z "$real_steam" ]; then
      echo "nix-crab: system Steam launcher not found on PATH" >&2
      exit 1
    fi

    LUMEN_DIR="$HOME/.local/share/Lumen"
    if [ -x "$LUMEN_DIR/lumen" ] \
      && ! ${lib.getExe' pkgs.procps "pgrep"} -f "$LUMEN_DIR/lumen" >/dev/null 2>&1; then
      ${lib.getExe' pkgs.util-linux "setsid"} "$LUMEN_DIR/lumen" >/dev/null 2>&1 </dev/null &
    fi

    exec "$real_steam" "$@"
  '';
in
{
  options.programs.nix-crab.luatools = {
    enable = lib.mkEnableOption ''
      the LuaTools stack: Lumen and its plugin under ~/.local/share/Lumen, a
      `lumen` command, and a `steam` wrapper that starts Lumen alongside Steam.
      Needs programs.nix-crab.slssteam-moon.enable on the NixOS side — that is
      the injection Lumen drives, and it is what brings steam-run, which the
      `lumen` launcher needs'';

    lumenService = lib.mkEnableOption ''
      a systemd user service for Lumen instead of the `steam` wrapper's sidecar.
      Lumen then starts at login (unit nix-crab-lumen, Restart=on-failure) and
      the `steam` command is no longer shadowed, so Steam launches plain and
      Lumen attaches once the CEF port appears'';
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      # Entry point for attaching to an already-running Steam. The launcher
      # installed by the activation below is the one place that knows how to
      # start Lumen (steam-run, backend dir, loader env).
      (pkgs.writeShellScriptBin "lumen" ''
        exec "$HOME/.local/share/Lumen/lumen" "$@"
      '')
    ]
    # Two independent start paths would fight over the same CEF target, so the
    # wrapper exists only in the sidecar mode.
    ++ lib.optional (!cfg.lumenService) steamWrapper;

    # Steam only publishes its CEF remote-debugging endpoint when this marker
    # exists; without it steamwebhelper starts with no debug port, nothing is
    # ever written to ~/.local/share/Lumen/cef_port and Lumen cannot attach. The
    # marker is read at client startup, so Steam needs a restart afterwards.
    home.activation.luatoolsCefMarker = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for root in "$HOME/.steam/steam" "$HOME/.steam/debian-installation"; do
        if [ -d "$root" ]; then
          touch "$root/.cef-enable-remote-debugging" 2>/dev/null || true
        fi
      done
    '';

    home.activation.luatoolsDist = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${
        lib.makeBinPath [
          pkgs.coreutils
          pkgs.findutils
        ]
      }:$PATH"

      stamps="${stampDir}"

      # Re-sync only when the pinned input changes or $4 forces it. Kept as a
      # plain predicate (not a call inside an `if` condition) so a failed copy
      # is never swallowed by errexit rules and reported as "up to date".
      needsSync() {
        src=$1
        dir=$2
        stamp=$3
        force=''${4:-0}
        if [ "$force" = 0 ] && [ -f "$stamp" ] \
          && [ "$(cat "$stamp")" = "$src" ] && [ -d "$dir" ]; then
          return 1
        fi
        return 0
      }

      # Copy a store dist into a writable directory. Only the files the PREVIOUS
      # dist installed are removed (the stamp names its store path), so the
      # state these dists deliberately exclude survives an input bump: cef_port,
      # notifications/ and ryuu_index.json under Lumen, backend/data and the logs
      # under the plugin.
      installDist() {
        src=$1
        dir=$2
        stamp=$3
        # A leftover copy from the store (or a half-finished install) is read-only
        # and would block both the removal and the overwrite below.
        run chmod -R u+w "$dir" 2>/dev/null || true
        if [ -f "$stamp" ]; then
          previous=$(cat "$stamp")
          if [ -d "$previous" ]; then
            (cd "$previous" && find . ! -type d) | while read -r file; do
              run rm -f "$dir/$file"
            done
          fi
        fi
        run mkdir -p "$dir"
        run cp -r "$src"/. "$dir"/
        run chmod -R u+w "$dir"
      }

      # Written last, so an install that dies halfway is retried on the next
      # switch instead of being recorded as current.
      writeStamp() {
        run mkdir -p "$stamps"
        tmp=$(mktemp)
        printf '%s' "$1" >"$tmp"
        run install -m644 "$tmp" "$2"
        rm -f "$tmp"
      }

      dir="${lumenDir}"
      src="${lumenDist}"
      stamp="$stamps/lumen-src"

      # The launcher is installed here rather than shipped in the dist, so a
      # directory without it — or with an older launcher — has to be rebuilt even
      # when the stamp still matches.
      force=0
      if [ ! -x "$dir/lumen" ] || ! grep -q 'env -u LD_AUDIT' "$dir/lumen" 2>/dev/null; then
        force=1
      fi

      if needsSync "$src" "$dir" "$stamp" "$force"; then
        installDist "$src" "$dir" "$stamp"
        run mv -f "$dir/lumen" "$dir/lumen.bin"
        run install -m755 ${launcher} "$dir/lumen"
        writeStamp "$src" "$stamp"
        echo "nix-crab: installed Lumen into $dir"
      else
        echo "nix-crab: Lumen is up to date"
      fi

      # The plugin lives inside Lumen's own luatools/ directory.
      plugin_dir="$dir/luatools"
      plugin_src="${pluginDist}"
      plugin_stamp="$stamps/luatools-src"
      if needsSync "$plugin_src" "$plugin_dir" "$plugin_stamp" 0; then
        installDist "$plugin_src" "$plugin_dir" "$plugin_stamp"
        writeStamp "$plugin_src" "$plugin_stamp"
        echo "nix-crab: installed the LuaTools plugin into $plugin_dir"
      else
        echo "nix-crab: the LuaTools plugin is up to date"
      fi
    '';

    # Managed alternative to the wrapper sidecar. ExecStart points at the launcher
    # the activation writes, which is what makes Lumen runnable at all (steam-run
    # sandbox, loader env unset).
    systemd.user.services.nix-crab-lumen = lib.mkIf cfg.lumenService {
      Unit = {
        Description = "Lumen backend for LuaTools (slsteam-moon)";
        After = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${lumenDir}/lumen";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
