# Retrosmart cursor theme — one scheme of the retrosmart-cursor fork.
#
# Upstream: https://github.laiyagushi.com/useless-anvil/retrosmart-cursor
# (fork of mdomlop/retrosmart-x11-cursors, GPL-3.0). Its pipeline recolors
# 32px XPM sources with an `outline` and a `fill` color, upscales them with
# ImageMagick, and writes binary Xcursor files with xcursorgen. The `mac-ish`
# artwork draws the cursor body with `outline` and its interior with `fill`.
#
# The upstream schemes.yaml names 28 schemes and the build renders all of
# them. This derivation replaces that file with the single scheme the flake
# wants, so one theme comes out instead of the 72 upstream ships.
#
# `_` prefix: raw package definition, callPackage'd by the feature's
# default.nix; import-tree must not auto-import it as a flake-parts module.
{
  lib,
  stdenvNoCC,
  imagemagick,
  xcursorgen,
  python3,
  src,
  version,
  schemeId,
  displayName,
  outline,
  fill,
}:
stdenvNoCC.mkDerivation {
  pname = "retrosmart-xcursor-${schemeId}";
  inherit version src;

  nativeBuildInputs = [
    imagemagick
    xcursorgen
    # build.sh reads schemes.yaml and data/hotspots.yaml through python3.
    (python3.withPackages (ps: [ ps.pyyaml ]))
  ];

  postPatch = ''
    # build.sh calls the ImageMagick 6 binary name; version 7 installs
    # `magick`, which takes the same arguments.
    sed -i 's/^\( *\)convert /\1magick /' build.sh

    cat > schemes.yaml <<'EOF'
    ${schemeId}:
      name: "${displayName}"
      outline: "${outline}"
      fill: "${fill}"
      cursors: "mac-ish"
    EOF
  '';

  # The steps of the upstream `all` target in order, minus the Windows
  # output: png rasterizes the recolored sources, in writes the xcursorgen
  # input files, cursors builds the Xcursor binaries and the aliases.
  # build.sh carries a `#!/usr/bin/env bash` shebang, which no build sandbox
  # has, so bash runs it.
  buildPhase = ''
    runHook preBuild
    bash build.sh png
    bash build.sh in
    bash build.sh cursors
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons"
    cp -r "build_themes/Linux/mac-ish/retrosmart-xcursor-${schemeId}" "$out/share/icons/"
    runHook postInstall
  '';

  meta = {
    description = "Retrosmart ${displayName} cursor theme, recolored with the dendritic sepia palette";
    homepage = "https://github.laiyagushi.com/useless-anvil/retrosmart-cursor";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
}
