# system/hardware-profiles — the nixos-hardware bridge

## Purpose
One registry of the [nixos-hardware](https://github.com/NixOS/nixos-hardware)
profiles this flake is willing to apply, plus the record of which ones each host
applies and why. It exists because the NixOS wiki's NVIDIA page says, under
"Tips and tricks", to check nixos-hardware for a device-specific quirk — and
that advice is worthless if it is re-derived from scratch every time someone
reads the page.

## Ownership
- `default.nix` — the registry. Publishes `flake.nixosHardwareProfiles`
  (declared in `modules/parts.nix`), an attrset of upstream module attrs keyed
  by their nixos-hardware attribute name. It exports **no** `flake.nixosModules`
  entry: nothing here is imported by name.
- This file — the coverage matrix below, which is the durable record.

## Local Contracts
- **Selection is static, not option-driven.** A NixOS module cannot import
  conditionally on its own `config` — `config.imports` built from an option
  value is the module system's documented infinite-recursion trap ("you
  probably reference `config` in `imports`"), and the upstream profiles set
  their values unconditionally, so they cannot be gated with `mkIf` from
  outside either. The import therefore lives in the host's module list, which
  is also the repo's own "import = enabling" convention
  (`modules/features/AGENTS.md`). Do not add a `dendritic.hardwareProfiles`
  option here; it has been tried and it recurses.
- **Hosts select by registry key.** Each host's
  `modules/hosts/<HOST>/_hardware-profiles-settings.nix` is a function
  `{ self, ... }: [ ...modules ]` that looks keys up in
  `self.nixosHardwareProfiles`, and `modules/hosts/<HOST>/default.nix` splices
  the resulting list onto its `modules`. A key that is not in the registry is
  an evaluation error ("attribute … missing"), which is the typo guard.
- **Adding a profile is two edits:** a row in `default.nix`, and the host's
  settings file. The matrix below is the third edit and is not optional — the
  table is the reason the registry exists.
- **The registry follows nixpkgs.** `flake.nix` pins `nixos-hardware` with
  `inputs.nixpkgs.follows = "nixpkgs"`, because every profile is a plain NixOS
  module that reads the host's `pkgs`/`lib`; a non-followed copy would evaluate
  against a second nixpkgs and duplicate store paths. Upstream publishes no
  tags, so the flake.lock rev is the only pin — see the README's
  known-boundaries entry.

## Coverage matrix

Re-verified against the locked rev `60a624466c08787ee8303393b7d4752d1826f14f`
(2026-10-11), which exposes 442 profiles, 25 of them `common-*`.

### NIXPC

Machine, from the 2026-10-15 scan: ASRock B450M Steel Legend (BIOS P10.60,
"To Be Filled By O.E.M." vendor string), AMD Ryzen 7 3700X (Zen 2 / Matisse),
NVIDIA GeForce RTX 3050 8 GiB at PCI `0000:07:00.0` (GA107, Ampere; driver
595.104.02, CUDA 13.2, open kernel modules), **no iGPU** — one display
controller and one `/sys/class/drm` card — NVMe boot disk, desktop.

| Profile | Verdict | Reason |
|---|---|---|
| `common-gpu-nvidia-nonprime` | **applied** | The one the wiki points at. A single Ampere dGPU with no iGPU is exactly the non-PRIME case. Upstream sets only `services.xserver.videoDrivers = lib.mkDefault [ "nvidia" ]`, which yields to `system/drivers/nvidia.nix`'s explicit list; its value is that a future upstream quirk lands here with no local edit. |
| `common-cpu-amd` | **applied** | Zen 2 microcode via `hardware.cpu.amd.updateMicrocode = mkDefault config.hardware.enableRedistributableFirmware`. Already true on this host; naming the profile keeps the value owned by upstream's default rather than a local hardcode. |
| `common-pc-ssd` | **applied** | `services.fstrim.enable = mkDefault true`. Already true here; same forward-looking reason. |
| `common-gpu-nvidia` | rejected | PRIME **offload**. Requires an iGPU; this host has none. |
| `common-gpu-nvidia-sync` | rejected | PRIME sync. No iGPU, and sync mode is X11-only — both hosts are Wayland-only (`services.xserver.enable = false`). |
| `common-gpu-nvidia-disable` | rejected | Blacklists nouveau/nvidia and removes the PCI device. The opposite of what this host needs. |
| `common-cpu-amd-pstate` | rejected | Sets `boot.kernelParams = [ "amd_pstate=active" ]` for any kernel ≥ 6.3 with **no CPU-family gate**. Ryzen 7 3700X is Zen 2 / Matisse; active-mode `amd_pstate` is not validated there and a wrong choice here costs a boot, not a rebuild. Revisit only with a measured frequency-scaling comparison. |
| `common-cpu-amd-raphael-igpu` | rejected | Raphael (Ryzen 7000) iGPU support. Wrong CPU generation. |
| `common-cpu-amd-zenpower` | rejected | Third-party `zenpower` kernel module for VRM temperature sensors. Not needed; one more out-of-tree module to rebuild per kernel bump. |
| `common-cpu-intel`, `common-cpu-intel-cpu-only` | rejected | Intel microcode path. AMD host. |
| `common-gpu-amd`, `-sea-islands`, `-southern-islands` | rejected | AMD GPU drivers. No AMD GPU. |
| `common-gpu-intel*` (5 profiles) | rejected | Intel GPU drivers. No Intel GPU. |
| `common-hidpi` | rejected | Console font + `console.earlySetup`, both `mkIf` on kernel < 6.8. This host runs 7.2.9, so the module is a no-op even if imported. NIXPC's panels are 1080p. |
| `common-networking-intel-x550` | rejected | Intel X550 NIC firmware. The board's Realtek NIC is covered by `linux-firmware`. |
| `common-pc` | rejected | Its only content is `boot.blacklistedKernelModules = [ "ath3k" ]` when `!hardware.enableRedistributableFirmware`. This host sets that option true, so it is a no-op. |
| `common-pc-hdd` | rejected | Upstream-deprecated no-op (emits a deprecation warning). |
| `common-pc-laptop`, `-laptop-ssd`, `-laptop-hdd` | rejected | `services.tlp.enable` and friends. This is a desktop with no battery. |
| `common-pc-laptop-acpi_call` | rejected | Upstream `throw`s on import — the module was removed upstream. |
| the other 417 vendor profiles | not applicable | nixos-hardware has **no ASRock B450M Steel Legend profile** and no generic B450 profile. The vendor entries are laptop/mainboard models (Lenovo, Framework, Tuxedo, Xiaomi, Dell, ASUS, Apple, …). Nothing to import; the quirk coverage for this board is what `system/drivers/nvidia.nix` and the host module carry by hand. |

### ASAHI

Machine: Apple Silicon (aarch64-linux), MangoWM + Niri + Noctalia.

| Profile | Verdict | Reason |
|---|---|---|
| every profile | rejected | nixos-hardware has **no Apple Silicon profile**. Its `apple-*` entries stop at Intel T2 Macs (`apple-t2`, `apple-macbook-pro-11-5`, …); there is no asahi/m1/m2/m3 key. ASAHI's quirks come from the `nixos-apple-silicon` input instead (`flake.nix`), which owns the bootchain, the asahi kernel modules, and the Apple firmware. |

ASAHI's `_hardware-profiles-settings.nix` is therefore `[ ]` on purpose: the
empty list keeps the file's shape identical to NIXPC's, so adding a profile
later is a one-line edit rather than a decision about whether the host opts in.

## Work Guidance
- A new host: scan it (`lspci -nn`, `/sys/class/dmi/id/*`, `/proc/cpuinfo`,
  `nvidia-smi`), write its `_hardware-profiles-settings.nix`, and add a
  machine block to the matrix above before merging.
- Never add a registry row without a matrix row saying why, and never delete
  a matrix row when a profile is rejected — the rejection *is* the record.
- When `nix flake update` moves the nixos-hardware rev, re-read the upstream
  `common/` tree for new profiles and re-check the rejected rows: a new
  `common-*` profile can invalidate a rejection.

## Verification
- `nix-instantiate --parse modules/system/hardware-profiles/default.nix`
- `nix eval --raw .#nixosHardwareProfiles --apply 'builtins.attrNames'`
  (registry keys) — and the same for a host, to prove the splice reached the
  config: `nix eval --impure .#nixosConfigurations.NIXPC.config.services.fstrim.enable`
- `nix flake check --impure` covers both hosts through their `modules` lists.
