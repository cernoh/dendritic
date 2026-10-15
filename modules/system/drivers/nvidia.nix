# The NVIDIA driver aspect, audited against https://nixos.wiki/wiki/Nvidia.
#
# This is the cross-host NVIDIA aspect: it stays host-agnostic and carries no
# machine facts. Machine facts (which nixos-hardware profile applies, which
# GPU family) live in modules/system/hardware-profiles and in each host's
# `_hardware-profiles-settings.nix`.
#
# What the wiki asks for, and where it is:
#   hardware.graphics.enable                    -> below
#   services.xserver.videoDrivers = ["nvidia"]  -> below
#   hardware.nvidia.open = true                 -> below (Turing or newer)
#   hardware.nvidia.modesetting.enable = true   -> below (Wayland needs KMS)
#   hardware.nvidia.powerManagement.enable      -> below (suspend/resume fix)
#
# What is deliberately NOT set, and why:
#
#   hardware.nvidia.prime.* — NIXPC has one display controller and no iGPU
#     (lspci shows a single 0000:07:00.0 NVIDIA GA107; /sys/class/drm has one
#     card). PRIME offload/sync/reverse-sync are hybrid-graphics options, so
#     enabling any of them on this machine would be wrong, not merely unused.
#     ASAHI is Apple Silicon and does not import this module at all.
#
#   hardware.nvidia.forceFullCompositionPipeline — an X11 tearing fix. Both
#     hosts are Wayland-only (services.xserver.enable = false; the greeter
#     starts MangoWM directly), so the option has no surface to act on.
#
#   boot.initrd.kernelModules = [ "nvidia" ] — the wiki lists this only under
#     "Booting to text mode" troubleshooting, and this host does not boot to
#     text mode. nixpkgs' own `boot.kernelModules = [ "nvidia" "nvidia_modeset"
#     "nvidia_drm" ]` is gated on `services.xserver.enable`, which is false
#     here, so the modules load through udev modalias instead (`nvidia` and
#     `nvidia_drm` both carry `pci:v000010DEd*` aliases; `nvidia_modeset`
#     arrives as a symbol dependency of `nvidia_drm`, and `nvidia_uvm` is
#     listed explicitly elsewhere). If a text-mode boot ever appears, add that
#     line first — do not pre-emptively change the boot chain.
#
# Explicit sync (driver >= 555, which improves Wayland frame pacing) needs no
# option: it is a wp_linux-drm-syncobj-v1 negotiation between the driver and
# the compositor, and the driver side is on from 555 onward.
#
# nixpkgs already owns, and this module must not duplicate:
#   boot.extraModulePackages, boot.extraModprobeConfig
#   (`blacklist nouveau/nvidiafb`, `softdep nvidia post: nvidia-uvm`,
#   `options nvidia-drm fbdev=1 modeset=1`), the /dev/nvidia* udev rules, and
#   hardware.graphics.extra{,32}Packages — which is where nvidia-vaapi-driver
#   comes from, through hardware.nvidia.videoAcceleration (nixpkgs default).
{
  self,
  inputs,
  ...
}:
{
  flake.nixosModules.nvidiaDrivers =
    {
      lib,
      pkgs,
      ...
    }:
    {
      services.xserver.videoDrivers = [ "nvidia" ];

      environment.systemPackages = with pkgs; [
        vulkan-tools
      ];

      hardware = {
        graphics = {
          enable = true;
          # 32-bit GL/Vulkan for Steam and Wine; nixpkgs fills
          # extraPackages32 from the driver's own lib32 output.
          enable32Bit = true;
        };
        nvidia = {
          modesetting.enable = true;

          # The wiki's fix for graphical corruption and crashes on
          # suspend/resume: `powerManagement.enable = false` (the nixpkgs
          # default) is exactly the state it says can corrupt. On driver >=
          # 595 with the open modules, nixpkgs'
          # `hardware.nvidia.powerManagement.kernelSuspendNotifier` defaults
          # to true, so the driver is notified by the kernel rather than by
          # the nvidia-suspend/nvidia-resume systemd units — the modern path,
          # with no unit to race the greeter.
          #
          # Caveat carried from the wiki: when enabled, the driver saves video
          # memory to `nvidia.NVreg_TemporaryFilePath`, which defaults to
          # /tmp. A tmpfs /tmp smaller than the VRAM in use fails to resume.
          # NIXPC's /tmp is on the root btrfs volume (237 GiB free), so no
          # `boot.kernelParams = [ "nvidia.NVreg_TemporaryFilePath=/var/tmp" ]`
          # is needed. Re-check that before enabling this on a host whose
          # /tmp is tmpfs.
          #
          # The wiki also warns the option is itself unstable and can cause
          # suspend issues. Revert this single line if that happens.
          powerManagement.enable = true;

          # Turing or newer (RTX 20 / GTX 16 series and up) — the open modules
          # are preferred upstream and planned to replace the proprietary
          # ones. Data-center GPUs from Grace Hopper/Blackwell onward *must*
          # use them. The userspace half stays proprietary either way, so
          # `nixpkgs.config.allowUnfree = true` (system/core/nix-settings.nix)
          # is still required.
          #
          # Note: modules/system/hardware-profiles applies nixos-hardware's
          # `common-gpu-nvidia-nonprime`, whose own `open` uses
          # `lib.mkOverride 990` and therefore outranks this plain assignment.
          # Both resolve to `true` for an open-capable package, so the two are
          # value-identical by design; this line keeps the aspect working when
          # it is imported without the profile.
          open = true;

          nvidiaSettings = true;
        };
      };
    };
}
