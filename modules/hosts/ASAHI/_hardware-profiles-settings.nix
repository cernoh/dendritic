# ASAHI's nixos-hardware coverage: none.
#
# nixos-hardware carries no Apple Silicon profile. Its `apple-*` entries stop
# at Intel T2 Macs (`apple-t2`, `apple-macbook-pro-11-5`, …), and there is no
# asahi/m1/m2/m3 key in the registry. ASAHI's quirks come from the
# `nixos-apple-silicon` input instead (flake.nix), which owns the bootchain,
# the asahi kernel modules, and the Apple-specific firmware.
#
# The empty list is the assertion, not an omission: it keeps the shape of this
# file identical to NIXPC's, so adding a profile later is a one-line edit here
# rather than a decision about whether the host opts in at all.
{ self, ... }:

[ ]
