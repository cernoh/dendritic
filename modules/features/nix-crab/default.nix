# nix-crab — declarative h3adcr-b equivalent for Steam on NIXPC.
#
# Two module halves, together the whole feature:
#   * nixosModules.nix-crab — the injection (SLSsteam/slsteam-moon through
#     LD_AUDIT), the CloudRedirect LD_PRELOAD hook, Millennium's overlay and the
#     client-downgrade tool. Importing it also injects the home-manager half,
#     which is why the host needs one import and not two.
#   * homeManagerModules.nix-crab — SLSsteam's config.yaml, the CloudRedirect
#     Flatpak app and the files its own checks stat, the two CLI commands, and
#     the optional app/addon stacks (ACCELA, SteaMidra, Millennium addons,
#     LuaTools).
#
# Every artifact (SLSsteam, slsteam-moon, CloudRedirect + CLI, netsock, Lumen,
# the LuaTools plugin, Millennium, ACCELA's bundle, SteamIdra's tag list) is
# pinned by the `nix-crab` input, which is now a pin carrier and nothing else:
# the modules below are this repo's own implementation, so nothing upstream can
# break the eval by changing shape. Bumping that input still moves every pin at
# once, and is the one review step: read upstream's flake.nix to see what moved.
#
# Enable switches live here, not in the host, because this feature is the whole
# Steam stack: the toggles below are the set this flake is built around.
{
  self,
  inputs,
  ...
}:
let
  pinned = inputs.nix-crab.inputs;
in
{
  flake.nixosModules.nix-crab = {
    imports = [
      (import ./_millennium.nix { inherit (pinned) millennium; })
      (import ./_cloudredirect.nix { inherit (pinned) cloudredirect cloudredirect-moon; })
      (import ./_slssteam.nix { inherit (pinned) sls-steam slsteam-moon; })
      ./_downgrade.nix
    ];

    programs.nix-crab.slssteam.enable = true;
    programs.nix-crab.cloudredirect.enable = true;
    programs.nix-crab.downgrade.enable = true;

    # Millennium stays OFF. Its pinned `millennium-typescript-bun-deps`
    # fixed-output hash no longer matches what `bun install --frozen-lockfile`
    # produces at the pinned rev, so realizing the system dies in a hash mismatch
    # before Steam is reached:
    #   specified: sha256-BEupNhAlkAELGGLj6/SVUjj101hBm4JzJH9N5i1qM6A=
    #   got:       sha256-QFY5nzgCcvurpHkLapChs1A7ce+FnKwY92rkskUADFc=
    # The module is `lib.mkIf`-gated and the overlay is lazy, so with the option
    # off `pkgs.steam` is plain nixpkgs Steam and the injection module's override
    # is the base. That hash is upstream's, not ours: re-enabling means bumping
    # the millennium input to a revision whose hash is current, then flipping
    # this to true and checking that `millennium-typescript-bun-deps` realizes.
    programs.nix-crab.millennium.enable = false;

    # The LuaTools stack (slsteam-moon + Lumen) is the mutually exclusive
    # alternative to Millennium and is likewise off; see _luatools.nix.
    programs.nix-crab.slssteam-moon.enable = false;

    # `accela` and `steamidra` are home-manager options — upstream declares them
    # on the home half only, and so do the modules here.
    home-manager.sharedModules = [ self.homeManagerModules.nix-crab ];
  };

  flake.homeManagerModules.nix-crab = {
    imports = [
      (import ./_home.nix {
        inherit (pinned)
          sls-steam
          steamnetsock
          cloudredirect
          cloudredirect-moon
          cloudredirect-cli
          ;
        # This repo's own nix-flatpak, never the copy nix-crab pins: two copies
        # of the module would declare `services.flatpak` twice.
        inherit (inputs) nix-flatpak;
      })
      ./_addons.nix
      (import ./_luatools.nix { inherit (pinned) lumen luatools-moon; })
      (import ./_steamidra.nix { inherit (pinned) steamidra; })
      (import ./_accela.nix { inherit (pinned) accela; })
    ];

    programs.nix-crab.accela.enable = true;
    programs.nix-crab.steamidra.enable = true;

    # The LuaTools frontend, and the moon hook for the CloudRedirect link, stay
    # off with the rest of that stack. `slssteam.manageConfig` keeps its own
    # default (false), so SteaMidra can edit config.yaml.
  };
}
