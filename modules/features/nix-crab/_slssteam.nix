# Steam client injection: which 32-bit audit objects Steam loads via LD_AUDIT.
#
# Two implementations ship the same pair of objects (SLSsteam.so +
# library-inject.so): upstream SLSsteam, prebuilt by its own flake, and
# slsteam-moon, which adds a native Lua manifest importer and ships no flake, so
# it is compiled here. The option picks one store path; everything downstream —
# CloudRedirect's LD_PRELOAD, Millennium's overlay, `nix-crab-status` — is
# fork-agnostic.
{ sls-steam, slsteam-moon }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nix-crab;

  # Same toolchain upstream uses for its own package: the two audit objects are
  # loaded into Steam's 32-bit client, so the objects and their direct NEEDED
  # (openssl, curl) have to be i686 even on an x86_64 host.
  moon = pkgs.pkgsi686Linux.stdenv.mkDerivation {
    pname = "slsteam-moon";
    version = "unstable";

    src = slsteam-moon;

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = with pkgs.pkgsi686Linux; [
      openssl
      curl
    ];

    # pattern-refresh is a native host helper that is never injected; only the
    # two objects Steam dlopens are built.
    buildPhase = "make bin/SLSsteam.so bin/library-inject.so";

    # ~100 translation units at -O3 -flto. The Makefile only marks `clean`
    # and `rebuild` .NOTPARALLEL, so the object targets take -j fine.
    enableParallelBuilding = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/SLSsteam.so "$out/SLSsteam.so"
      install -Dm755 bin/library-inject.so "$out/library-inject.so"
      runHook postInstall
    '';

    meta = {
      description = "SLSsteam fork with a Lua manifest importer";
      homepage = "https://github.com/swwayps/slsteam-moon";
      license = lib.licenses.agpl3Only;
      platforms = lib.platforms.linux;
    };
  };

  fork =
    if cfg.slssteam-moon.enable then
      moon
    else
      sls-steam.packages.${pkgs.stdenv.hostPlatform.system}.sls-steam;

  # Name the fork in the derivation so the injection is identifiable at runtime:
  # `nix-crab-status` reads the live LD_AUDIT out of /proc and matches this
  # string. (A fork-blind name is why upstream's own `Fork:` line always reads
  # "none" while Steam is running.)
  forkTag = if cfg.slssteam-moon.enable then "moon" else "upstream";

  # The prebuilt objects carry a RUNPATH onto their own glibc/libstdc++
  # (glibc-2.42-67 + gcc-15.3.0-lib). Steam's FHS environment already has a
  # 32-bit libc loaded (glibc-multi-2.42-61 + gcc-15.2.0-lib) and the loader
  # honours that RUNPATH, so a second libc.so.6 lands in the same 32-bit
  # process. The stack canary is then written by one libc and checked by the
  # other, and every 32-bit program dies with "*** stack smashing detected ***".
  # Dropping the RUNPATH makes the loader reuse the libc that is already there;
  # the direct NEEDED (openssl, curl) stay reachable through Steam's own
  # environment.
  audit =
    pkgs.runCommandLocal "SLSsteam-audit-${forkTag}" { nativeBuildInputs = [ pkgs.patchelf ]; }
      ''
        install -d "$out"
        install -m755 ${fork}/SLSsteam.so ${fork}/library-inject.so "$out"
        for object in "$out"/*.so; do
          patchelf --remove-rpath "$object"
        done
      '';
in
{
  options.programs.nix-crab = {
    slssteam.enable = lib.mkEnableOption "SLSsteam injection into Steam";

    slssteam.extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Extra environment variables for the wrapped Steam. This is also the
        channel CloudRedirect uses to add its LD_PRELOAD, which is why it lives
        on the injection option rather than on a Steam option of its own
        (`programs.steam.extraEnv` is not an option — it is an argument to
        `pkgs.steam.override`).
      '';
    };

    slssteam-moon.enable = lib.mkEnableOption ''
      slsteam-moon instead of upstream SLSsteam — a SLSsteam fork with a native
      Lua manifest importer, built from source here. Takes precedence over
      slssteam.enable; it is the injection the LuaTools stack drives'';
  };

  config = lib.mkIf (cfg.slssteam.enable || cfg.slssteam-moon.enable) {
    programs.steam = {
      enable = true;

      package = pkgs.steam.override {
        extraEnv = {
          LD_AUDIT = "${audit}/library-inject.so:${audit}/SLSsteam.so";
        }
        // cfg.slssteam.extraEnv;

        # The FHS wrapper never binds /sys, and bubblewrap starts from a fresh
        # mount namespace where /sys does not exist — the auto-mount loop cannot
        # bind a mountpoint onto itself. Mesa then cannot resolve
        # /sys/dev/char/226:* or /sys/class/drm, reports "failed to retrieve
        # device information", refuses to load i915/iris and falls back to
        # llvmpipe; Steam's 32-bit vgui2 gets no GLX visual and fatal-asserts on
        # "glXChooseVisual failed". read-only is all it needs.
        extraBwrapArgs = [ "--ro-bind /sys /sys" ];
      };
    };
  };
}
