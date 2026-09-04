# Roblox via Sober (flatpak org.vinegarhq.Sober) for NIXPC (issue #122).
#
# Sober ships only as a Flatpak app, so this feature composes the `flatpak`
# service and the `portals` system module it requires (services.flatpak
# asserts xdg.portal.enable). A Flatpak app cannot be declared hermetically
# from Nix, so the install runs at activation time and only when the app is
# not installed yet (the first switch on the host). The install needs
# network access to flathub; a failed install prints the retry command and
# does not abort the switch. Later updates run via `flatpak update`.
#
# Sober publishes x86_64 builds only; on other architectures the activation
# install stays inert while the flatpak/portals imports remain harmless.
{ self, lib, ... }:
{
  flake.nixosModules.sober =
    {
      pkgs,
      ...
    }:
    {
      imports = with self.nixosModules; [
        flatpak
        portals
      ];

      system.activationScripts.sober = lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 (
        lib.mkAfter ''
          # Activation scripts run with a minimal PATH (no systemPackages), so
          # call the flatpak binary by its store path.
          if ! ${pkgs.flatpak}/bin/flatpak list --system --app --columns=application 2>/dev/null | grep -qx 'org.vinegarhq.Sober'; then
            echo "sober: org.vinegarhq.Sober not installed; fetching from flathub"
            ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo \
              && ${pkgs.flatpak}/bin/flatpak install --system --noninteractive --assumeyes flathub org.vinegarhq.Sober \
              || echo "sober: setup failed; retry with: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install --system flathub org.vinegarhq.Sober" >&2
          fi
        ''
      );
    };
}
