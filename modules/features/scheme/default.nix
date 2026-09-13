# Sepia color scheme — the single source of truth for the flake-wide palette.
#
# Read it from any nix file via the flake output:
#   self.scheme.name             # "sepia" — the theme name consumers pass on
#   self.scheme.mode             # "dark"
#   self.scheme.palette.<role>   # bare hex, no leading '#' (niri/mango style)
#   self.scheme.hex.<role>       # "#rrggbb"
#   self.scheme.rgb.<role>       # "r g b" decimal, for KDL
#   self.scheme.base16.<slot>    # 16 editor slots, "#rrggbb" (nvf)
#   self.scheme.ansiNormal.<name> / ansiBright.<name>   # terminal colors
#   self.scheme.noctalia         # Noctalia palette document
#   self.scheme.greeter          # greeter.toml [appearance.palette]
#   self.scheme.omp              # omp theme token map
#   self.scheme.wallpaper        # host wallpaper path
#
# Every value derives from `palette`, so a role change propagates to every
# consumer. Repointing the whole desktop means editing `palette` here and
# nothing else.
#
# Consumers that cannot read nix values keep a copy, with a comment naming this
# file:
#   - modules/features/niri/config.kdl (static config, symlinked out-of-store)
#   - modules/features/noctalia/plugins/terminal/service.luau (Luau sandbox)
{
  lib,
  ...
}:
let
  # Semantic roles. `base` is the application background, `surface` the bar and
  # panel background, `text` the primary foreground. The accents stay warm, so
  # the whole desktop reads as one sepia print.
  palette = {
    crust = "120e0b";
    mantle = "17120e";
    base = "1e1813";
    surface = "241d17";
    surfaceVariant = "302619";
    surfaceHighlight = "3a2f21";
    overlay = "463829";
    border = "40342a";
    outline = "5f4d3a";

    text = "ece0cd";
    textMuted = "c9b79c";
    textDim = "9c8c74";

    primary = "c99a5b";
    onPrimary = "241c12";
    primaryContainer = "6b4f2a";
    onPrimaryContainer = "f3e0c4";

    secondary = "c9a3a0";
    onSecondary = "2a1f1e";

    tertiary = "a8a06a";
    onTertiary = "241f12";

    error = "c56a5a";
    onError = "2a1512";
    warning = "d9b06a";
    success = "8f9a6a";
    info = "8a9bb0";

    shadow = "0f0c09";
    hover = "3a2f21";
    onHover = "f3e9d8";
    selection = "57452f";
    onSelection = "f7f2e8";
  };

  # Prefix every value of a bare-hex attrset.
  hexOf = lib.mapAttrs (_: value: "#${value}");
  hex = hexOf palette;

  hexDigit = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  };
  byte =
    value: index:
    hexDigit.${builtins.substring index 1 value} * 16
    + hexDigit.${builtins.substring (index + 1) 1 value};
  toRgb = value: "${toString (byte value 0)} ${toString (byte value 2)} ${toString (byte value 4)}";

  # base16 slots: 00-07 backgrounds and foregrounds, 08-0F accents.
  base16 = hexOf {
    base00 = palette.base;
    base01 = palette.surface;
    base02 = palette.surfaceHighlight;
    base03 = palette.outline;
    base04 = palette.textDim;
    base05 = palette.text;
    base06 = palette.onHover;
    base07 = "fbf6ee";
    base08 = palette.error;
    base09 = "cf8f5c";
    base0A = palette.warning;
    base0B = palette.success;
    base0C = "7d9a8e";
    base0D = palette.info;
    base0E = palette.secondary;
    base0F = "8a6a4a";
  };

  # Terminal colors. A consumer that needs the ANSI index order reads the two
  # attrsets in the documented key order (black, red, green, yellow, blue,
  # magenta, cyan, white).
  ansiNormal = {
    black = "#2a231a";
    red = "#c56a5a";
    green = "#8f9a6a";
    yellow = "#d9b06a";
    blue = "#8a9bb0";
    magenta = "#c9a3a0";
    cyan = "#7d9a8e";
    white = "#c9b79c";
  };
  ansiBright = {
    black = "#5f4d3a";
    red = "#d98470";
    green = "#a9b47f";
    yellow = "#e8c98a";
    blue = "#a3b3c6";
    magenta = "#dcb9c0";
    cyan = "#96b0a5";
    white = "#f3e9d8";
  };

  # Noctalia palette document. `dark` is REQUIRED: the shell parses the file
  # with the community-palette reader, which rejects a document without a
  # `dark` object and falls back to the builtin palette. `light` is omitted,
  # so the shell reuses the dark variant in both modes.
  noctalia = {
    dark = {
      mPrimary = hex.primary;
      mOnPrimary = hex.onPrimary;
      mSecondary = hex.secondary;
      mOnSecondary = hex.onSecondary;
      mTertiary = hex.tertiary;
      mOnTertiary = hex.onTertiary;
      mError = hex.error;
      mOnError = hex.onError;
      mSurface = hex.base;
      mOnSurface = hex.text;
      mSurfaceVariant = hex.surfaceVariant;
      mOnSurfaceVariant = hex.textMuted;
      mOutline = hex.outline;
      mShadow = hex.shadow;
      mHover = hex.hover;
      mOnHover = hex.onHover;

      terminal = {
        background = hex.base;
        foreground = hex.text;
        cursor = hex.primary;
        cursorText = hex.onPrimary;
        selectionBg = hex.selection;
        selectionFg = hex.onSelection;
        normal = ansiNormal;
        bright = ansiBright;
      };
    };
  };

  # omp theme tokens. Every required color of the theme schema is present: a
  # missing token makes omp fall back to the `dark` built-in. See
  # `omp://theme.md`.
  omp = {
    accent = hex.primary;
    border = hex.border;
    borderAccent = hex.primary;
    borderMuted = hex.outline;
    success = hex.success;
    error = hex.error;
    warning = hex.warning;
    muted = hex.textMuted;
    dim = hex.textDim;
    text = hex.text;
    thinkingText = hex.textDim;

    selectedBg = hex.selection;
    userMessageBg = hex.surface;
    customMessageBg = hex.surfaceVariant;
    toolPendingBg = hex.surface;
    toolSuccessBg = hex.surfaceVariant;
    toolErrorBg = hex.surfaceHighlight;
    statusLineBg = hex.mantle;

    userMessageText = hex.text;
    customMessageText = hex.text;
    customMessageLabel = hex.primary;
    toolTitle = hex.text;
    toolOutput = hex.textMuted;

    mdHeading = hex.primary;
    mdLink = hex.info;
    mdLinkUrl = hex.textDim;
    mdCode = hex.onPrimaryContainer;
    mdCodeBlock = hex.onPrimaryContainer;
    mdCodeBlockBorder = hex.outline;
    mdQuote = hex.textMuted;
    mdQuoteBorder = hex.outline;
    mdHr = hex.outline;
    mdListBullet = hex.primary;

    toolDiffAdded = hex.success;
    toolDiffRemoved = hex.error;
    toolDiffContext = hex.textDim;

    syntaxComment = hex.textDim;
    syntaxKeyword = hex.secondary;
    syntaxFunction = hex.primary;
    syntaxVariable = hex.text;
    syntaxString = hex.success;
    syntaxNumber = hex.warning;
    syntaxType = hex.tertiary;
    syntaxOperator = hex.info;
    syntaxPunctuation = hex.textMuted;

    thinkingOff = hex.outline;
    thinkingMinimal = hex.textDim;
    thinkingLow = hex.info;
    thinkingMedium = hex.tertiary;
    thinkingHigh = hex.primary;
    thinkingXhigh = hex.error;
    thinkingMax = hex.secondary;
    bashMode = hex.info;
    pythonMode = hex.tertiary;

    statusLineSep = hex.outline;
    statusLineModel = hex.secondary;
    statusLinePath = hex.primary;
    statusLineGitClean = hex.success;
    statusLineGitDirty = hex.warning;
    statusLineContext = hex.info;
    statusLineSpend = hex.tertiary;
    statusLineStaged = hex.success;
    statusLineDirty = hex.warning;
    statusLineUntracked = hex.error;
    statusLineOutput = hex.text;
    statusLineCost = hex.warning;
    statusLineSubagents = hex.secondary;
  };
in
{
  options.flake.scheme = lib.mkOption {
    type = lib.types.raw;
    description = "Flake-wide color scheme: name, mode, palette, and derived documents.";
  };

  config.flake.scheme = {
    name = "sepia";
    mode = "dark";

    inherit
      palette
      hex
      base16
      ansiNormal
      ansiBright
      noctalia
      omp
      ;
    rgb = lib.mapAttrs (_: toRgb) palette;

    # greeter.toml [appearance.palette]: the same 16 roles, renamed to the
    # snake_case keys the greeter reads.
    greeter = {
      primary = hex.primary;
      on_primary = hex.onPrimary;
      secondary = hex.secondary;
      on_secondary = hex.onSecondary;
      tertiary = hex.tertiary;
      on_tertiary = hex.onTertiary;
      error = hex.error;
      on_error = hex.onError;
      surface = hex.base;
      on_surface = hex.text;
      surface_variant = hex.surfaceVariant;
      on_surface_variant = hex.textMuted;
      outline = hex.outline;
      shadow = hex.shadow;
      hover = hex.hover;
      on_hover = hex.onHover;
    };

    # The host wallpaper. A store path is fine: Noctalia and the greeter only
    # read the file.
    wallpaper = ./wallpapers/monet-water-lilies.jpg;
  };
}
