# Fastpotify — native Spotify client (issue #132).
#
# Upstream: https://github.com/crmne/fastpotify (Rust/egui + librespot).
# Consumed from its own nix flake (perSystem re-export, davinci shape).
#
# DRM note: no Widevine involvement. Playback goes through librespot
# (Spotify Premium session, rodio/cpal sink), not a browser CDM, so the
# ASAHI widevine module is unrelated. Upstream's flake lists aarch64-linux
# and CI builds aarch64-unknown-linux-gnu natively — safe on Asahi.
#
# Opt in from a host:
#   modules = with self.nixosModules; [ fastpotify ];
{
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.fastpotify = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = with self'.packages; [
        fastpotify
      ];
    }
  );
  perSystem =
    { inputs', ... }:
    {
      packages.fastpotify = inputs'.fastpotify.packages.fastpotify;
    };
}
