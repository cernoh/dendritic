# ghostty-term — PTY-backed terminal emulator for the Noctalia terminal plugin.
#
# Built on libghostty-vt, the terminal emulator core from Ghostty. The plugin
# itself runs in a Luau sandbox with no foreign function interface, so it cannot
# call this library directly; this helper owns the pseudo-terminal and the
# terminal state, and reports each screen change as one JSON frame.
#
# pkgs.libghostty-vt is the standalone packaging of the library, separate from
# pkgs.ghostty (which ships only the sequence parsers under the same soname).
# It provides the terminal, render-state, and formatter APIs this helper uses.
{
  lib,
  stdenv,
  pkg-config,
  libghostty-vt,
}:

stdenv.mkDerivation {
  pname = "ghostty-term";
  version = "1.0.0";

  # One translation unit. Copy nothing else into the store, and skip the
  # unpack phase: there is no archive to extract.
  dontUnpack = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libghostty-vt ];

  buildPhase = ''
    runHook preBuild
    $CC -std=c11 -O2 -Wall -Wextra -Werror \
      $(pkg-config --cflags libghostty-vt) \
      ${./ghostty-term.c} \
      $(pkg-config --libs libghostty-vt) \
      -o ghostty-term
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ghostty-term $out/bin/ghostty-term
    runHook postInstall
  '';

  meta = {
    description = "PTY-backed terminal emulator for the Noctalia terminal plugin";
    longDescription = ''
      Runs a shell on a pseudo-terminal, feeds its output into libghostty-vt,
      and writes the resulting screen as one JSON frame per change. The Noctalia
      terminal plugin reads those frames and draws the shell output with the
      real colors and the real cursor position.
    '';
    license = lib.licenses.mit;
    mainProgram = "ghostty-term";
    platforms = lib.platforms.linux;
  };
}
