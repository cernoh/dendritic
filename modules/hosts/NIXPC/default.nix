{
  self,
  inputs,
  ...
}:
let
  # nixos-hardware machine-quirk profiles for this host. The registry is
  # modules/system/hardware-profiles; the names and the reasons are in
  # _hardware-profiles-settings.nix. Spliced statically, not driven by an
  # option: a module cannot import conditionally on its own `config`.
  hardwareProfiles = import ./_hardware-profiles-settings.nix { inherit self; };
in
{
  flake.nixosConfigurations.NIXPC = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      with self.nixosModules;
      [
        # See core: consumes /etc/nixos/hardware-configuration.nix only when
        # evaluated on this machine; placeholder root fs elsewhere.
        (self.lib.hardwareFromMachine "x86_64-linux")

        desktop
        nixpcConfiguration
        nixpcDesktop
        nvidiaDrivers
        # smartmontools + smartd over the NVMe and the three SATA disks, plus
        # the noctalia drive-health plugin's root collector as a declared
        # service/timer pair; see system/disk-health.
        diskHealth
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
        # The herdr daemon itself: `herdr server` as a systemd user service, so
        # the multiplexer every other herdr thing below attaches to is owned by
        # a unit instead of by whichever client connected first. Importing this
        # is the whole enable switch; the NixOS half injects the home-manager
        # module through `home-manager.sharedModules`.
        herdr
        # The herdr-web bridge. This import is the whole enable switch: the NixOS
        # module also adds homeManagerModules.herdr-web to the user's Home
        # Manager, so the server runs on loopback and this half publishes it on
        # the tailnet, which is how the phone reaches it over HTTPS. ASAHI does
        # not import it: no agent runs there, and the bridge would grant it
        # terminal control of every pane.
        herdr-web
        ({ services.herdr-web.tailscaleServe.enable = true; })
        # The second herdr client UI (chat view, file viewer, remote PCs, push
        # alerts) runs beside the bridge above on its own port. Same split: the
        # home-manager module runs the server on loopback, this publishes it on
        # the tailnet. Neither bridge starts the herdr daemon — `herdr` above
        # does, and both are ordered after it — so a daemon is already answering
        # when either connects. NIXPC only, and the package's node_modules FOD
        # hash is the x86_64 dependency tree, so building it on another
        # architecture fails the hash.
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
        # Pi-Bolt: the same Pi coding agent compiled ahead of time to one
        # native executable. It reads the very same ~/.pi/agent tree that
        # `pi-coding-agent` (from attrs/programming) owns, so settings,
        # extensions, skills and the sepia theme are shared rather than
        # duplicated. NIXPC only, for the same reason as wayfinder-dashboard
        # and herdr-web: ASAHI does not run coding agents. The pinned x64
        # build needs AVX2; see features/pi-bolt/AGENTS.md for the pin, the
        # variant table, and why the binary must not be re-patched.
        pi-bolt
      ]
      ++ hardwareProfiles;
  };
}
