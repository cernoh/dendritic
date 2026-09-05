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
      # Builtin theme name tracks the flake-wide default
      # (self.catppuccin.default, modules/features/catppuccin): "mocha" ->
      # "Catppuccin Mocha". A static file cannot read nix values; this
      # wrapper can, so repointing the default needs no manual sync.
      flavor = self.catppuccin.default;
      themeName =
        "Catppuccin "
        + lib.toUpper (builtins.substring 0 1 flavor)
        + builtins.substring 1 (builtins.stringLength flavor - 1) flavor;

      # Flake-owned settings, previously modules/features/ghostty/config.
      configFlags = [
        "--font-family=Monofur Nerd Font"
        "--font-size=14"
        "--window-padding-x=10"
        "--window-padding-y=10"
        "--window-theme=dark"
        "--macos-option-as-alt=true"
        "--background-opacity=0.85"
        "--background-blur=true"
        "--theme=${themeName}"
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
      # Monofur is the active ghostty family; Droid Sans Mono rides along
      # for editor/UI use.
      fonts.packages = with pkgs.nerd-fonts; [
        droid-sans-mono
        monofur
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
