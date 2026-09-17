# Mirai (Miracast daemon + CLI), built from the pinned `mirai` flake input
# (`flake = false`, so this file's nixpkgs builds it).
#
# Not upstream's `default.nix` verbatim: Mirai resolves its helper binaries from
# absolute paths compiled into `mirai/config.py` (`/usr/bin/miracle-wifid`,
# `/usr/bin/miracle-sinkctl`, `/usr/lib/gnome-network-displays-stream`), which
# do not exist on NixOS. `wrapProgram --set` points those environment
# overrides at this closure instead, so the daemon started from the wrapper
# resolves every helper regardless of who invokes it.
#
# The wrapper also owns PATH: the daemon shells out to `iw`, `ip`,
# `avahi-browse`, `wlr-randr`, `gst-launch-1.0` and `mpv` by bare name, and it
# writes a player script that runs `python3 -m mirai gst-player`, so python3,
# PYTHONPATH, and every probe binary must be on the daemon's PATH.
#
# `_` prefix: raw package definition — import-tree must not auto-import it as a
# flake-parts module; features/noctalia/default.nix callPackages it.
{
  lib,
  stdenv,
  src,
  python3,
  python3Packages,
  makeWrapper,
  miraclecast,
  gnome-network-displays,
  gst_all_1,
  mpv,
  avahi,
  iw,
  iproute2,
  which,
  wlr-randr,
  xrandr,
}:

let
  # Everything Mirai spawns by bare name, plus the two binaries it needs only
  # for its own probe calls (`which`, `gst-inspect-1.0`).
  runtimePath = lib.makeBinPath [
    python3
    miraclecast
    gnome-network-displays
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    mpv
    avahi
    iw
    iproute2
    which
    wlr-randr
    xrandr
  ];
in
stdenv.mkDerivation {
  pname = "mirai";
  version = "0.1.0"; # upstream has no tags; pinned revision below

  inherit src;

  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  # Upstream's default Makefile target installs into /usr/local, which the
  # build sandbox refuses, so the build phase is a no-op and installPhase
  # below does the work.
  buildPhase = ":";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share
    cp -r mirai $out/lib/mirai
    cp -r quickshell $out/share/mirai-quickshell
    install -Dm755 bin/mirai $out/bin/mirai
    install -Dm644 systemd/mirai.service $out/lib/systemd/system/mirai.service

    substituteInPlace $out/bin/mirai \
      --replace-fail "exec python3 -m mirai" "exec ${python3}/bin/python3 -m mirai"

    wrapProgram $out/bin/mirai \
      --prefix PATH : "${runtimePath}" \
      --prefix PYTHONPATH : "$out/lib:${python3Packages.dbus-python}/${python3.sitePackages}" \
      --set MIRACLE_WIFID "${miraclecast}/bin/miracle-wifid" \
      --set MIRACLE_SINKCTL "${miraclecast}/bin/miracle-sinkctl" \
      --set GNOME_NETWORK_DISPLAYS_STREAM "${gnome-network-displays}/libexec/gnome-network-displays-stream"

    runHook postInstall
  '';

  meta = {
    description = "Miracast daemon and CLI for Linux";
    homepage = "https://github.com/Leriart/Mirai";
    license = lib.licenses.gpl2Plus;
    mainProgram = "mirai";
    platforms = lib.platforms.linux;
  };
}
