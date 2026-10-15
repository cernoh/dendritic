# The nixos-hardware registry: which upstream machine-quirk modules this flake
# is willing to apply, published as data so hosts name them by key.
#
# https://nixos.wiki/wiki/Nvidia says it plainly under "Tips and tricks":
# "The nixos-hardware project attempts to provide configurations that address
# specific hardware quirks for different devices. It is possible that someone
# already wrote a hardware configuration for your device." This file is how
# that advice is honoured declaratively instead of being re-derived by hand
# every time the wiki is re-read.
#
# Why a registry and not a `dendritic.hardwareProfiles` option: a module
# cannot import conditionally on its own `config` — `config.imports` built
# from an option value is the documented infinite-recursion trap
# ("you probably reference `config` in `imports`"), and the upstream profiles
# set their values unconditionally, so they cannot be gated with `mkIf` from
# outside either. The import therefore has to be static, which means it lives
# in the host's module list — the repo's own "import = enabling" convention
# (features/AGENTS.md).
#
# What this registry buys over writing `inputs.nixos-hardware.nixosModules.x`
# in each host: one table, so the set of profiles this flake will apply is
# readable in one place, and a host naming a key that is not here fails
# evaluation with "attribute missing" instead of silently importing nothing.
#
# Coverage decisions live in this directory's AGENTS.md as a matrix: which
# profiles were considered for each host, which were applied, and which were
# rejected with the reason. Read it before adding a key here — the matrix is
# the record, this table is only its enforcement.
#
# Input pinning: `nixos-hardware` follows `nixpkgs` (flake.nix) and is locked
# to a rev in flake.lock. Upstream publishes no tags, so `nix flake update`
# moves it; see the README's known-boundaries entry for what that can change.
{ inputs, ... }:

{
  flake.nixosHardwareProfiles = {
    # Single-GPU (non-PRIME) NVIDIA desktop. Upstream sets only
    # `services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ]`, which
    # yields to system/drivers/nvidia.nix's explicit list. Its value is
    # forward-looking: if upstream ever adds a quirk to the nonprime NVIDIA
    # profile, every host naming it picks it up with no local edit.
    common-gpu-nvidia-nonprime = inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime;
    # AMD CPU microcode, gated on `hardware.enableRedistributableFirmware`.
    common-cpu-amd = inputs.nixos-hardware.nixosModules.common-cpu-amd;
    # Periodic `fstrim` for SSD/NVMe-backed hosts.
    common-pc-ssd = inputs.nixos-hardware.nixosModules.common-pc-ssd;
  };
}
