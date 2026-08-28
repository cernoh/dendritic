# Catppuccin color scheme — the single source of truth for the flake-wide
# default scheme (Catppuccin Mocha).
#
# Read it from any other nix file via the flake output:
#   self.catppuccin.default        # "mocha" — flavor selector for nvf, tmux,
#                                  # zellij, … point at this so repointing
#                                  # the default is a one-line change
#   self.catppuccin.mocha          # full mocha palette; hex values WITHOUT
#                                  # the leading '#' (ghostty/niri style)
#   self.catppuccin.mocha.blue     # "89b4fa"
#
# App-level scheme selection that cannot take nix values stays in sync
# manually:
#   - ghostty (static config file, modules/features/ghostty/config):
#     `theme = Catppuccin Mocha` is the built-in theme matching
#     self.catppuccin.default.
#   - noctalia (builtin schemes, hosts/*): `Catppuccin` in dark mode ==
#     mocha; keep `darkMode = true` / `mode = "dark"`.
{ lib, ... }: {
  options.flake.catppuccin = lib.mkOption {
    type = lib.types.raw;
    description = "Catppuccin default flavor and palettes.";
  };

  config.flake.catppuccin = {
    # Default scheme flavor. Consumers read this, not a hardcoded string.
    default = "mocha";

    mocha = {
      rosewater = "f5e0dc";
      flamingo = "f2cdcd";
      pink = "f5c2e7";
      mauve = "cba6f7";
      red = "f38ba8";
      maroon = "eba0ac";
      peach = "fab387";
      yellow = "f9e2af";
      green = "a6e3a1";
      teal = "94e2d5";
      sky = "89dceb";
      sapphire = "74c7ec";
      blue = "89b4fa";
      lavender = "b4befe";
      text = "cdd6f4";
      subtext1 = "bac2de";
      subtext0 = "a6adc8";
      overlay2 = "9399b2";
      overlay1 = "7f849c";
      overlay0 = "6c7086";
      surface2 = "585b70";
      surface1 = "45475a";
      surface0 = "313244";
      base = "1e1e2e";
      mantle = "181825";
      crust = "11111b";
    };
  };
}
