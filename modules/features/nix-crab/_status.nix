# The two user-facing commands: a diagnostic report and a maintenance wrapper.
#
# Both are plain scripts with an explicit PATH, because they are run from an
# arbitrary shell (and from each other) and must not depend on what happens to
# be on the caller's PATH.
{
  cloudredirect,
  cloudredirect-moon,
}:
{
  lib,
  pkgs,
  ...
}:
let
  helpers = import ./_lib.nix;

  # The two hook files this flake can wire up, staged exactly as the injection
  # stages them, so the comparison below is against the real store path —
  # resolving the ~/.local/share link is what makes the report say which scanner
  # is actually reading the game list, instead of which one was intended.
  upstreamHook = "${helpers.hookStaged pkgs cloudredirect}/cloud_redirect.so";
  moonHook = "${helpers.hookStaged pkgs cloudredirect-moon}/cloud_redirect.so";

  commonPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.findutils
    pkgs.procps
  ];

  status = pkgs.writeShellScriptBin "nix-crab-status" ''
    set -u
    export PATH=${commonPath}:$PATH

    upstream_hook=${lib.escapeShellArg upstreamHook}
    moon_hook=${lib.escapeShellArg moonHook}

    mode=text
    for argument in "$@"; do
      case "$argument" in
        --json) mode=json ;;
        --help | -h)
          echo "usage: nix-crab-status [--json]"
          exit 0
          ;;
        *)
          echo "nix-crab-status: unknown argument: $argument" >&2
          exit 2
          ;;
      esac
    done

    home=$HOME
    slssteam_config=$home/.config/SLSsteam/config.yaml
    steam_cfg=$home/.steam/steam/steam.cfg
    netsock=$home/.config/SLSsteam/tools/netsock/netsock.so
    cr_link=$home/.local/share/CloudRedirect/cloud_redirect.so
    cr_cli=$home/.local/share/CloudRedirect/cloud_redirect_lib
    lumen_dir=$home/.local/share/Lumen

    # Flags are 1/0 so the two renderers share one probe pass; values that are
    # meant to be printed stay verbatim.
    flag() {
      if [ "$1" = 1 ]; then printf 'true'; else printf 'false'; fi
    }

    json_escape() {
      printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
    }

    json_string() {
      printf '"%s"' "$(json_escape "$1")"
    }

    # --- Steam client --------------------------------------------------------
    steam_version=""
    for manifest in "$home/.steam/steam/package"/steam_client_*; do
      [ -f "$manifest" ] || continue
      steam_version=$(grep -m1 '"version"' "$manifest" | awk -F'"' '{print $4}')
      [ -n "$steam_version" ] && break
    done
    manifest_note=""
    if [ -z "$steam_version" ]; then
      steam_version=unknown
      manifest_note="no manifest in $home/.steam/steam/package"
    fi

    updates_blocked=0
    [ -f "$steam_cfg" ] && updates_blocked=1

    # --- SLSsteam config -----------------------------------------------------
    # SLSsteam's yaml-cpp stack lets the LAST occurrence of a key win, which is
    # how SteaMidra's appended block can silently override the first one. Read
    # the last occurrence, and count them so a duplicate is visible.
    last_value() {
      grep "^$1:" "$slssteam_config" | tail -1 | awk '{print $2}'
    }

    config_present=0
    disable_cloud=""
    play_not_owned=""
    safe_mode=""
    disable_cloud_count=0
    if [ -f "$slssteam_config" ]; then
      config_present=1
      disable_cloud=$(last_value DisableCloud)
      play_not_owned=$(last_value PlayNotOwnedGames)
      safe_mode=$(last_value SafeMode)
      disable_cloud_count=$(grep -c '^DisableCloud:' "$slssteam_config")
    fi

    netsock_present=0
    [ -f "$netsock" ] && netsock_present=1

    # --- Injection in the live client ---------------------------------------
    # LD_AUDIT is inherited by every process Steam starts, so one scan of /proc
    # finds the loaded objects. The staging derivation names the fork, which is
    # how the two builds are told apart from the path alone.
    injection="unknown (Steam not running)"
    if pgrep -x steam >/dev/null 2>&1 || pgrep -x steamwebhelper >/dev/null 2>&1; then
      injection=none
      audit=""
      for environ in /proc/[0-9]*/environ; do
        [ -r "$environ" ] || continue
        # The group matters: procfs can deny the open even when the permission
        # test passed, and bash reports a failed redirection itself — outside the
        # command's own stderr redirect — so one group-level redirect quiets it.
        audit=$(
          {
            tr '\0' '\n' <"$environ" | grep -m1 '^LD_AUDIT='
          } 2>/dev/null || true
        )
        [ -n "$audit" ] && break
      done
      case "$audit" in
        *SLSsteam-audit-moon*) injection="slsteam-moon (LuaTools)" ;;
        *SLSsteam-audit-upstream*) injection="upstream SLSsteam" ;;
      esac
    fi

    # --- Games ---------------------------------------------------------------
    # slsteam-moon does not write added games into config.yaml (that section is
    # deprecated); they are <appid>.lua manifests under Steam's stplug-in dir,
    # plus whatever luaappids.yaml carries by hand.
    stplug=""
    for root in "$home/.steam/steam" "$home/.steam/debian-installation" "$home/.local/share/Steam"; do
      if [ -d "$root/config/stplug-in" ]; then
        stplug=$root/config/stplug-in
        break
      fi
    done
    lua_manifests=0
    if [ -n "$stplug" ]; then
      lua_manifests=$(find "$stplug" -maxdepth 1 -name '*.lua' 2>/dev/null | wc -l | tr -d ' ')
    fi
    luaappids=0
    [ -f "$home/.config/SLSsteam/luaappids.yaml" ] && luaappids=1

    # --- CloudRedirect -------------------------------------------------------
    # CloudRedirect only redirects while SLSsteam's cloud is enabled, and both
    # spellings of "not disabled" occur: YAML 1.2 true/false from the typed
    # module, YAML 1.1 yes/no from a hand-written or headcrab-era file.
    cloudredirect_enabled=0
    case "$disable_cloud" in
      no | false) cloudredirect_enabled=1 ;;
    esac

    cloudredirect_hook=missing
    if [ -e "$cr_link" ]; then
      hook_target=$(readlink -f "$cr_link" 2>/dev/null || true)
      case "$hook_target" in
        "$moon_hook") cloudredirect_hook="moon (LuaTools)" ;;
        "$upstream_hook") cloudredirect_hook=upstream ;;
        *) cloudredirect_hook="other: $hook_target" ;;
      esac
    fi

    cli_present=0
    [ -x "$cr_cli" ] && cli_present=1
    flatpak_installed=0
    [ -d "$home/.local/share/flatpak/app/org.cloudredirect.CloudRedirect" ] && flatpak_installed=1

    # --- LuaTools / Lumen ----------------------------------------------------
    lumen_installed=0
    [ -x "$lumen_dir/lumen" ] && [ -x "$lumen_dir/lumen.bin" ] && lumen_installed=1
    plugin_installed=0
    [ -d "$lumen_dir/luatools/backend" ] && plugin_installed=1
    lumen_running=0
    pgrep -f "$lumen_dir/lumen.bin" >/dev/null 2>&1 && lumen_running=1
    cef_port=0
    [ -f "$lumen_dir/cef_port" ] && cef_port=1

    if [ "$mode" = json ]; then
      printf '{'
      printf '"steam":{"version":%s,"manifest_note":%s,"updates_blocked":%s},' \
        "$(json_string "$steam_version")" \
        "$(json_string "$manifest_note")" \
        "$(flag "$updates_blocked")"
      printf '"slssteam":{"config_present":%s,"disable_cloud":%s,"play_not_owned":%s,"safe_mode":%s,"disable_cloud_duplicates":%s,"netsock_present":%s},' \
        "$(flag "$config_present")" \
        "$(json_string "$disable_cloud")" \
        "$(json_string "$play_not_owned")" \
        "$(json_string "$safe_mode")" \
        "$disable_cloud_count" \
        "$(flag "$netsock_present")"
      printf '"injection":%s,' "$(json_string "$injection")"
      printf '"games":{"stplug_in_dir":%s,"lua_manifests":%s,"luaappids_yaml":%s},' \
        "$(json_string "$stplug")" \
        "$lua_manifests" \
        "$(flag "$luaappids")"
      printf '"cloudredirect":{"enabled":%s,"hook":%s,"cli_present":%s,"flatpak_installed":%s},' \
        "$(flag "$cloudredirect_enabled")" \
        "$(json_string "$cloudredirect_hook")" \
        "$(flag "$cli_present")" \
        "$(flag "$flatpak_installed")"
      printf '"luatools":{"installed":%s,"plugin_installed":%s,"running":%s,"cef_port":%s}' \
        "$(flag "$lumen_installed")" \
        "$(flag "$plugin_installed")" \
        "$(flag "$lumen_running")" \
        "$(flag "$cef_port")"
      printf '}\n'
      exit 0
    fi

    echo "=== Steam Client ==="
    if [ "$steam_version" = unknown ]; then
      echo "Version:        unknown ($manifest_note)"
    else
      echo "Version:        $steam_version"
    fi
    if [ "$updates_blocked" = 1 ]; then
      echo "Upstream:       blocked (steam.cfg present)"
    else
      echo "Upstream:       follows Steam's updates"
    fi

    echo
    echo "=== SLSsteam ==="
    if [ "$config_present" = 1 ]; then
      echo "DisableCloud:   $disable_cloud"
      echo "PlayNotOwned:   $play_not_owned"
      echo "SafeMode:       $safe_mode"
      if [ "$disable_cloud_count" -gt 1 ]; then
        echo "Warning:        DisableCloud appears $disable_cloud_count times; only the last one counts"
      fi
    else
      echo "Config missing: $slssteam_config"
    fi
    if [ "$netsock_present" = 1 ]; then
      echo "Netsock:        present (per-game launch option only)"
    else
      echo "Netsock:        missing"
    fi

    echo
    echo "=== Injection (live Steam) ==="
    echo "Fork:           $injection"

    echo
    echo "=== Games (slsteam-moon / LuaTools) ==="
    if [ -n "$stplug" ]; then
      echo "stplug-in:      $lua_manifests lua manifests ($stplug)"
    else
      echo "stplug-in:      missing (no Steam root with config/stplug-in)"
    fi
    if [ "$luaappids" = 1 ]; then
      echo "luaappids.yaml: present (manual AdditionalApps list)"
    else
      echo "luaappids.yaml: none"
    fi

    echo
    echo "=== CloudRedirect ==="
    if [ "$cloudredirect_enabled" = 1 ]; then
      echo "Status:         enabled (DisableCloud: $disable_cloud)"
    else
      echo "Status:         disabled (DisableCloud: ''${disable_cloud:-unset})"
    fi
    echo "Hook:           $cloudredirect_hook"
    echo "CLI:            $([ "$cli_present" = 1 ] && echo present || echo missing)"
    echo "Flatpak:        $([ "$flatpak_installed" = 1 ] && echo installed || echo "not installed")"

    echo
    echo "=== LuaTools / Lumen ==="
    echo "Lumen:          $([ "$lumen_installed" = 1 ] && echo installed || echo "not installed (luatools.enable off?)")"
    echo "Plugin:         $([ "$plugin_installed" = 1 ] && echo installed || echo missing)"
    echo "Running:        $([ "$lumen_running" = 1 ] && echo yes || echo no)"
    echo "CEF endpoint:   $([ "$cef_port" = 1 ] && echo attached || echo "waiting (restart Steam after the first switch)")"
  '';

  update = pkgs.writeShellScriptBin "nix-crab-update" ''
    set -u
    export PATH=${commonPath}:$PATH

    if [ ! -f flake.nix ]; then
      echo "nix-crab-update: no flake.nix in $PWD — run it from the configuration repo" >&2
      exit 1
    fi

    echo "== nix flake update =="
    nix flake update || exit 1

    if command -v nh >/dev/null 2>&1; then
      echo "== nh os switch =="
      nh os switch || echo "nh os switch failed (see above)" >&2
      echo "== nh home switch =="
      nh home switch || echo "nh home switch failed (see above)" >&2
    elif command -v nixos-rebuild >/dev/null 2>&1; then
      echo "== nixos-rebuild switch =="
      sudo nixos-rebuild switch --flake . || echo "nixos-rebuild failed (see above)" >&2
      if command -v home-manager >/dev/null 2>&1; then
        echo "== home-manager switch =="
        home-manager switch --flake . || echo "home-manager switch failed (see above)" >&2
      fi
    else
      echo "nix-crab-update: neither nh nor nixos-rebuild is on PATH — inputs updated, nothing switched" >&2
    fi

    echo
    echo "== nix-crab-status =="
    if command -v nix-crab-status >/dev/null 2>&1; then
      nix-crab-status || true
    else
      echo "nix-crab-status is not on PATH (home module disabled?)"
    fi
  '';
in
{
  config.home.packages = [
    status
    update
  ];
}
