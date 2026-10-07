{
  self,
  inputs,
  ...
}:
{
  flake.nixosConfigurations.NIXPC = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = with self.nixosModules; [
      # See core: consumes /etc/nixos/hardware-configuration.nix only when
      # evaluated on this machine; placeholder root fs elsewhere.
      (self.lib.hardwareFromMachine "x86_64-linux")

      desktop
      nixpcConfiguration
      nixpcDesktop
      nvidiaDrivers
      gaming
      flatpakNixpc
      programming
      mango
      # Wayland + XWayland toolkit, portals, and the polkit/keyring pair that
      # keeps sudo and GUI auth prompts rare. Both hosts run MangoWM.
      wayland
      noctalia
      ghostty
      noctaliaGreeter
      ({ services.displayManager.noctalia-greeter.greeter-args = "--session Mango"; })
      # tailscaled (services.tailscale). ASAHI imports the same module; the
      # daemon needs a one-time `sudo tailscale up` per machine.
      tailscale
      # Build host half of the ASAHI link (issue #209): a `remotebuild` SSH
      # account that only ASAHI's root can use, and that account in
      # trusted-users. ASAHI imports the matching client module. The link
      # addresses NIXPC by its tailnet name, so both halves need tailscale.
      remoteBuilder
      # The herdr-web bridge runs from the home-manager module; this module
      # publishes it on the tailnet, so the phone reaches it over HTTPS.
      # ASAHI does not import it: no agent runs there.
      herdr-web
      ({ services.herdr-web.tailscaleServe.enable = true; })
      # The second herdr client UI (chat view, file viewer, remote PCs, push
      # alerts) runs beside the bridge above on its own port. Same split: the
      # home-manager module runs the server on loopback, this publishes it on
      # the tailnet. Both try the tailnet and neither starts the herdr daemon,
      # so the order they come up in does not matter.
      herdr-web-ui
      ({ services.herdr-web-ui.tailscaleServe.enable = true; })
      # The Docker daemon comes in through attrs/desktop -> act -> docker;
      # importing `docker` here as well would define the module twice and
      # duplicate the docker extraGroup entry (mcpContainers and paseo below
      # only need the daemon to exist).
      mcpContainers
      # Paseo daemon + bundled web UI in a container, on the tailnet.
      paseo
      # Mobile Wayfinder ticket queue. The user service controls GitHub,
      # Herdr, and Pi; this NixOS half publishes it over tailnet HTTPS.
      # NIXPC only: ASAHI does not run agents.
      wayfinder-dashboard
      ({ services.wayfinder-dashboard.tailscaleServe.enable = true; })
    ];
  };
}
