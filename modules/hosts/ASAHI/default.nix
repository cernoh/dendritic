{
  self,
  inputs,
  ...
}:
let
  # nixos-hardware machine-quirk profiles for this host: none. nixos-hardware
  # has no Apple Silicon profile, so the list is empty — see
  # _hardware-profiles-settings.nix. Spliced statically, not driven by an
  # option: a module cannot import conditionally on its own `config`.
  hardwareProfiles = import ./_hardware-profiles-settings.nix { inherit self; };
in
{
  flake.nixosConfigurations.ASAHI = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    modules =
      with self.nixosModules;
      [
        # Consumes /etc/nixos/hardware-configuration.nix only when evaluated
        # on this machine; placeholder root fs elsewhere. Without this gate,
        # evaluating ASAHI from NIXPC injected x86_64-linux as
        # nixpkgs.hostPlatform and refused aarch64-only packages (#16).
        (self.lib.hardwareFromMachine "aarch64-linux")

        desktop
        asahiConfiguration
        asahiPlatform
        widevine
        niri
        # MangoWM runs beside niri (issue #245): the greeter below starts mango
        # by default, niri stays installed as the second session. The feature
        # reads this host's facts from hosts/ASAHI/_mango-settings.nix.
        mango
        # Wayland + XWayland toolkit and the polkit/keyring pair. It owns the
        # portal stack for both hosts, so no direct `portals` import here (the
        # flatpak feature also imports `portals`; the import is idempotent).
        wayland
        noctalia
        ghostty
        programming
        noctaliaGreeter
        watt
        timeSync
        tailscale
        # NO `distributedBuilds` here, deliberately. It used to hand this Mac's
        # aarch64 work to NIXPC over the tailnet (issue #209). This host now
        # builds every derivation it installs locally; asahiConfiguration.nix
        # forces `nix.buildMachines = []` so the link cannot come back through
        # any other route. See modules/system/AGENTS.md and ASAHI/RESCUE.md.
        flatpakAsahi
        obs
        ({ services.displayManager.noctalia-greeter.greeter-args = "--session Mango"; })

        # Keyboard layout: `gb` variant `mac` — "English (UK, Macintosh)" in
        # xkeyboard-config. The keymap follows macOS UK, not the US ANSI keycaps
        # soldered to this keyboard: Shift+3 is £, and € / # sit on the third
        # level of 2 / 3 (ISO_Level3_Shift). Every other habit stays US: Shift+2
        # is @ and ` / ~ stay on the key next to left Shift, both because the
        # `mac` variant defines them so. Locales stay en_GB — only the keymap
        # changes. Must match dendritic.mango.xkbRulesLayout = "gb(mac)" in
        # _mango-settings.nix, which is the layer that actually types.
        ({
          services.xserver.xkb = {
            layout = "gb";
            variant = "mac";
          };
          console.keyMap = "gb";
        })
      ]
      ++ hardwareProfiles;
  };
}
