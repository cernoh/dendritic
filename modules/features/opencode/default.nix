# OpenCode agent CLI configuration, ported from
# ~/.config/home-manager-v3/config/opencode (kept/dropped decision: KEPT —
# the opencode state database was still receiving writes in August 2026, so
# it remains in the tool rotation next to omp).
#
# Opt in from a home-manager configuration:
#   imports = [ self.homeManagerModules.opencode ];
#
# The whole tree is exposed out-of-store via mkOutOfStoreSymlink into this
# checkout (nvf/niri pattern), so agents/skills/commands stay live-editable
# without a rebuild. The tracked tree is the v3 content minus node_modules
# and other untracked runtime data.
#
# The CLI itself ships from nixpkgs here; v3 relied on an out-of-band
# profile install.
{
  ...
}:
{
  flake.homeManagerModules.opencode =
    {
      config,
      pkgs,
      ...
    }:
    {
      home.file.".config/opencode".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/dendritic/modules/features/opencode/home";

      home.packages = with pkgs; [
        opencode
      ];
    };
}
