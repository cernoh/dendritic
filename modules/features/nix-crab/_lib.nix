# Shared primitives for the nix-crab modules.
#
# `_`-prefixed so `import-tree` never registers this file as a flake-parts
# module; every module that needs it imports it explicitly.
rec {
  # A CloudRedirect binary can arrive in two legal shapes, and the pinned inputs
  # use both: a `type = "file"` input IS the store object (the release asset),
  # while the moon fork is a git checkout with the `.so` at the repo root.
  # LD_PRELOAD and the staging copy both need a path to a regular file, so the
  # shape is resolved here instead of hardcoding one spelling — `install` on the
  # input's directory form fails with "not a directory" and takes the whole Steam
  # closure down with it.
  hookFile =
    src:
    let
      inCheckout = "${toString src}/cloud_redirect.so";
    in
    if builtins.pathExists inCheckout then inCheckout else toString src;

  # The loader takes a path verbatim, so the input's own store name would work,
  # but it is opaque (`-source` for a file input) and the CloudRedirect app's
  # deploy check looks for a file called cloud_redirect.so. Stage it under the
  # name the loader, the docs and the CLI all expect.
  #
  # Both module halves call this with the same `pkgs` and the same input, so the
  # resulting derivation is identical and dedupes to ONE store path — which is
  # what lets `nix-crab-status` recognise the inline hook by path instead of by
  # guessing from a filename.
  hookStaged =
    pkgs: src:
    pkgs.runCommandLocal "cloud_redirect.so" { } ''
      install -Dm755 ${hookFile src} "$out/cloud_redirect.so"
    '';
}
