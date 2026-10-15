# NIXPC's nixos-hardware coverage: the machine-quirk modules this host imports,
# named by key in the registry at modules/system/hardware-profiles/default.nix.
# The coverage matrix that records what was considered and rejected lives in
# modules/system/hardware-profiles/AGENTS.md.
#
# Machine facts this selection encodes, from the 2026-10-15 system scan:
#
#   Board      ASRock B450M Steel Legend (BIOS P10.60), "To Be Filled By
#              O.E.M." vendor string — nixos-hardware has no ASRock profile.
#   CPU        AMD Ryzen 7 3700X (Zen 2 / Matisse, AuthenticAMD)
#   GPU        NVIDIA GeForce RTX 3050 8 GiB, PCI 0000:07:00.0, GA107
#              (Ampere). Driver 595.104.02, CUDA 13.2, open kernel modules.
#   iGPU       none — one display controller, one /sys/class/drm card.
#   Boot disk  NVMe (fstrim applies).
{ self, ... }:

let
  profiles = self.nixosHardwareProfiles;
in
[
  # The GPU profile. This is the one the wiki points at, and the reason the
  # input exists at all: an Ampere dGPU on a non-PRIME desktop.
  profiles.common-gpu-nvidia-nonprime
  # Zen 2 microcode. Resolves through `hardware.enableRedistributableFirmware`
  # (true on both hosts), so it keeps the value owned by upstream's default
  # rather than by a local hardcode.
  profiles.common-cpu-amd
  # The NVMe boot disk is trimmed weekly. Already true here; naming the
  # profile keeps it true if the local default ever changes.
  profiles.common-pc-ssd
]
