# Millennium addons: plugins and themes, resolved from steambrew.app by ID.
#
# Downloaded at activation rather than fetched into the store, because both
# stores serve an addon's newest commit — a pinned hash would break on every
# upstream release — and because Millennium writes into these folders (its own
# settings and updater), which the store forbids.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nix-crab.millennium;

  # The two addon kinds do not live together on Linux: plugins follow
  # MILLENNIUM__PLUGINS_PATH (the XDG data home), themes follow Millennium's
  # internal get_millennium_path(), which is the Steam directory. The stamp that
  # records what this module installed stays next to the plugins.
  pluginsDir = "${config.xdg.dataHome}/millennium/plugins";
  themesDir = "${config.home.homeDirectory}/.steam/steam/millennium/themes";
  stampDir = "${config.xdg.dataHome}/millennium/.nix-crab";

  # An empty ID would match the first entry of the store index (`startswith("")`
  # is true for everything) and install an arbitrary addon.
  ids =
    configured:
    lib.warnIf (lib.elem "" configured)
      "nix-crab: ignoring an empty addon ID in programs.nix-crab.millennium"
      (lib.filter (id: id != "") configured);
in
{
  options.programs.nix-crab.millennium = {
    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "3dc714a7c1b1" ];
      description = ''
        Millennium plugin IDs from https://steambrew.app/plugins — the `id` in a
        plugin's store URL. Each is installed into
        ~/.local/share/millennium/plugins on activation unless it is already
        there.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "1wwKwvHrFuzMs7Kb1Uzu"
        "Adwaita"
      ];
      description = ''
        Millennium themes from https://steambrew.app/themes — the `id` in a
        theme's store URL, or its display name or GitHub repo name, whichever is
        at hand. Installed into ~/.steam/steam/millennium/themes on activation;
        pick the active theme in Millennium's own UI afterwards.
      '';
    };
  };

  # Deliberately not gated on the lists being non-empty: emptying a list has to
  # run too, or removing the last ID would leave that addon installed forever.
  config = {
    home.activation.millenniumAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      export PATH="${
        lib.makeBinPath [
          pkgs.curl
          pkgs.jq
          pkgs.unzip
        ]
      }:$PATH"

      stamps="${stampDir}"

      # kind, target directory, index endpoint, jq program resolving an ID to
      # "<zip url>|<folder>|<metadata.json>", then the configured IDs.
      syncKind() {
        kind=$1
        dir=$2
        api=$3
        program=$4
        shift 4

        # Only stamped addons are ever removed — whatever was installed by hand
        # through Millennium's UI stays where it is.
        for stamp in "$stamps/$kind"-*; do
          [ -e "$stamp" ] || continue
          id=$(basename "$stamp")
          id=''${id#"$kind"-}
          wanted=0
          for wanted_id in "$@"; do
            [ "$wanted_id" = "$id" ] && wanted=1
          done
          if [ "$wanted" = 1 ]; then
            continue
          fi
          folder=$(cat "$stamp")
          if [ -n "$folder" ]; then
            run rm -rf "$dir/$folder"
          fi
          run rm -f "$stamp"
          echo "nix-crab: removed $kind '$id'"
        done

        index=""
        for id in "$@"; do
          stamp="$stamps/$kind-$id"

          # The stamp alone is not enough: if the folder it names is gone
          # (deleted by hand, or left over from an older layout), install again.
          if [ -e "$stamp" ] && [ -d "$dir/$(cat "$stamp")" ]; then
            continue
          fi

          if [ -z "$index" ]; then
            if ! index=$(curl -fsS "$api"); then
              echo "nix-crab: $kind store unreachable" >&2
              return 0
            fi
          fi

          entry=$(printf '%s' "$index" | jq -r --arg id "$id" "$program")
          if [ -z "$entry" ] || [ "$entry" = null ]; then
            echo "nix-crab: no Millennium $kind '$id' in the store" >&2
            continue
          fi

          IFS='|' read -r url folder metadata <<< "$entry"

          tmp=$(mktemp -d)
          # Every archive here holds a single top-level folder, so `mv` renames
          # it to the canonical name — and fails loudly if that ever stops being
          # true instead of silently nesting one more level.
          if curl -fsSL -o "$tmp/a.zip" "$url" && unzip -qo "$tmp/a.zip" -d "$tmp/x"; then
            run mkdir -p "$dir" "$stamps"
            run rm -rf "$dir/$folder"
            run mv "$tmp"/x/* "$dir/$folder"
            if [ -n "$metadata" ]; then
              printf '%s' "$metadata" >"$tmp/metadata.json"
              run install -m644 "$tmp/metadata.json" "$dir/$folder/metadata.json"
            fi
            printf '%s' "$folder" >"$tmp/stamp"
            run install -m644 "$tmp/stamp" "$stamps/$kind-$id"
            echo "nix-crab: installed $kind '$folder'"
          else
            echo "nix-crab: install failed for $kind '$id'" >&2
          fi
          rm -rf "$tmp"
        done
      }

      # The store URL carries the first 12 characters of initCommitId while the
      # download endpoint wants all 40; startswith accepts either spelling.
      syncKind plugin "${pluginsDir}" https://steambrew.app/api/v1/plugins '
        first(.[] | select(.initCommitId | startswith($id)))
        | "https://steambrew.app/api/v1/plugins/download?id=\(.initCommitId)&n=\(.pluginJson.name)|\(.pluginJson.name)|"
      ' ${lib.escapeShellArgs (ids cfg.plugins)}

      # Themes have no single canonical handle: accept the ID, the display name
      # or the repo name. The metadata.json is what Millennium writes after its
      # own install, and its updater needs it to know which commit is on disk.
      syncKind theme "${themesDir}" https://steambrew.app/api/v2 '
        first(.[] | select(.data.id == $id or .name == $id or .data.github.repo == $id))
        | "\(.download)|\(.data.github.repo)|"
          + ({owner: .data.github.owner, repo: .data.github.repo, commit: .commit_data.oid} | tojson)
      ' ${lib.escapeShellArgs (ids cfg.themes)}
    '';
  };
}
