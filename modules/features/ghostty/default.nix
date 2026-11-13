# Ghostty terminal feature: GPU-accelerated terminal emulator.
#
# Homeless config (issue #126, policy #93): every ghostty config key is also
# a CLI flag (`--<key>=<value>`, see `ghostty --help`), so the flake-owned
# settings are baked into a `ghostty` wrapper (symlinkJoin over pkgs.ghostty,
# mango pattern) instead of an HM-owned ~/.config/ghostty file. The wrapper
# is a system package — identical on every host, moves with the generation.
#
# Wrapper shape: `+action` invocations pass through untouched (actions take
# only their own flags; `+show-config` goes quiet when config flags precede
# it, so flags would be dead weight there). Emulator runs get the flake flags
# prepended; `-e` composes after them (the `ghostty -e top` form used by
# Noctalia's terminalCommand and Mango's SUPER,T via $TERMINAL is unchanged).
#
# COLOURS ARE NOT SET HERE. They come from the Dux shell's dynamic theming:
# DMS's matugen integration writes `~/.config/ghostty/themes/dankcolors` from
# the current wallpaper, and the wrapper only names that theme. Two facts fix
# the shape of this file:
# - an explicit colour key always beats a `theme`, in any order (verified:
#   `background` stays put even when `theme` is set after it), so the wrapper
#   must not pass `--background`/`--foreground`/`--palette`/`--cursor-*` at
#   all. Keeping them would pin the terminal to the build-time palette and
#   silently ignore every matugen run.
# - a missing theme is not an error (verified: ghostty keeps the other values
#   and exits 0), so the terminal still starts on a machine where matugen has
#   not run yet — it just shows ghostty's own colours until the shell paints.
{
  self,
  ...
}:
{
  flake.nixosModules.ghostty =
    {
      pkgs,
      lib,
      ...
    }:
    let
      # The palette is NOT from modules/features/scheme. DMS's dynamic theming
      # owns terminal colour now: matugen writes the theme file and the wrapper
      # points ghostty at it (`theme` = a name under ~/.config/ghostty/themes).
      configFlags = [
        # DMS matugen output; regenerated on every wallpaper/theme change.
        "--theme=dankcolors"

        # Cascadia Code NF draws a dotted zero and ships a real italic face.
        # The italic face alone carries `ss01`, which swaps f, l, r and s for
        # their cursive alternates; the regular face has no `ss01`, so plain
        # text keeps its forms. `zero` swaps in the slashed glyph, and
        # `font-style-italic` pins the italic face instead of letting ghostty
        # synthesize an oblique. All of these belong to the family, so they sit
        # beside it.
        "--font-family=Cascadia Code NF"
        "--font-style-italic=Italic"
        "--font-feature=ss01"
        "--font-feature=zero"
        "--font-size=11"
        "--window-padding-x=10"
        "--window-padding-y=10"
        "--window-theme=dark"
        "--macos-option-as-alt=true"
        "--background-opacity=0.85"
        "--background-blur=true"
        "--cursor-style=block"
      ];

      ghosttyWrapped = pkgs.symlinkJoin {
        name = "ghostty-wrapped";
        paths = [ pkgs.ghostty ];
        postBuild = ''
          rm -f "$out/bin/ghostty"
          cat > "$out/bin/ghostty" <<'WRAPPER'
          #!${pkgs.runtimeShell}
          real="${pkgs.ghostty}/bin/ghostty"
          case "''${1-}" in
            +*) exec "$real" "$@" ;;
            *) exec "$real" ${lib.escapeShellArgs configFlags} "$@" ;;
          esac
          WRAPPER
          chmod +x "$out/bin/ghostty"
        '';
      };
    in
    {
      # Cascadia Code NF is the active ghostty family; Droid Sans Mono rides
      # along for editor/UI use.
      fonts.packages = [
        pkgs.cascadia-code
        pkgs.nerd-fonts.droid-sans-mono
      ];

      environment.systemPackages = [ ghosttyWrapped ];
    };

  flake.homeManagerModules.ghostty = { ... }: {
    # Compositor bindings spawn "$TERMINAL" (Mango's SUPER,T). The session
    # root compositor is greeter-spawned and never sources ~/.profile, so
    # sessionVariables alone never reaches spawn_shell's non-login `sh -c`.
    # TERMINAL is registered into mango's settings.env inside the mango
    # feature module instead: nixpkgs' module system rejects any definition
    # of an option that is not declared on the host — including mkIf-false
    # ones — so a guarded def here would break every non-mango host (issue
    # #86). NIXPC pairs mango with ghostty, so the entry is unconditional.
    # Kept alongside the wrapper: it still serves login shells (SSH, PTYs).
    home.sessionVariables.TERMINAL = "ghostty";
  };
}
