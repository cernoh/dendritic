# Core bundle: imported by every host. Composes the base system modules
# nothing can live without.
#
# Machine-generated disk layout is deliberately NOT imported here — hosts
# wire it themselves via `flake.lib.hardwareFromMachine` below.
{
  self,
  ...
}:
{
  flake.nixosModules.core =
    {
      lib,
      pkgs,
      ...
    }:
    let
      modules = with self.nixosModules; [
        user
        bootloader
        nixSettings
        hardware
        locale
      ];
    in
    {
      imports = modules;

      services = {
        openssh.enable = true;
        avahi = {
          enable = true;
          nssmdns4 = true;
          openFirewall = true;
        };
      };

      environment.systemPackages = with pkgs; [
        vim
        wget
        curl
        git
        unzip
        p7zip
        usbutils
        lsof
        gvfs
        libnotify
      ];

      # mkDefault so hosts whose machines were installed on a later NixOS
      # release can override upward without priority fights (ASAHI: 25.11).
      system.stateVersion = lib.mkDefault "25.05";
    };

  # Deploy-time machine facts stay out of the repo by design (voidarc
  # convention): every install regenerates them at
  # /etc/nixos/hardware-configuration.nix.
  #
  # That file also carries the machine's `nixpkgs.hostPlatform`. Importing it
  # unconditionally leaks the EVALUATING machine's architecture into every
  # host: evaluating ASAHI (aarch64) on NIXPC pulled in x86_64-linux and made
  # the module system build ASAHI's packages for the wrong platform
  # (alsa-ucm-conf-asahi refusal, issue #16).
  #
  # Hosts therefore consume the local file only while evaluating themselves
  # on their own machine. Anywhere else (CI, another host), a placeholder
  # root filesystem keeps the configuration evaluable end-to-end:
  #   nix eval --impure --raw \
  #     .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath
  flake.lib.hardwareFromMachine =
    system:
    { lib, ... }:
    let
      hardwareFile = /etc/nixos/hardware-configuration.nix;
      # `builtins.currentSystem` disappears under pure/restricted eval, so
      # select it defensively: there we always take the placeholder branch,
      # which is exactly right for CI-style evaluations.
      evalSystem = builtins.currentSystem or null;
      onMachine = evalSystem == system && builtins.pathExists hardwareFile;
    in
    {
      imports = lib.optional onMachine hardwareFile;

      fileSystems."/" = lib.mkIf (!onMachine) {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      warnings = lib.optionals (!onMachine) [
        (
          if evalSystem == system then
            "hardwareFromMachine ${system}: /etc/nixos/hardware-configuration.nix not found on this machine (evaluating as ${system} but ${toString hardwareFile} missing) — placeholder root filesystem in use. Fix: sudo rm /etc/nixos # if dangling symlink; sudo mkdir -p /etc/nixos; sudo cp /etc/nixos.backup.*/hardware-configuration.nix /etc/nixos/hardware-configuration.nix  OR  sudo nixos-generate-config --show-hardware-config > /tmp/hw.nix && sudo cp /tmp/hw.nix ${toString hardwareFile}"
          else
            "hardwareFromMachine ${system}: /etc/nixos/hardware-configuration.nix not consumed — placeholder root filesystem (cross-machine evaluation mode)."
        )
      ];
    };
}
