# Programming bundle, mirroring attrs/gaming: composes existing features by
# name instead of copying them.
#   - System side: lazygit ships via environment.systemPackages.
#   - Home-manager side (editor + dev env): import self.homeManagerModules.programming;
#     system/home-manager already enables it for the primary user alongside nvf/omp.
{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.programming = moduleWithSystem (
    { ... }:
    let
      modules = with self.nixosModules; [
        lazygit
      ];
    in
    {
      # Editor env for login shells, systemd user units and any process not
      # started from an interactive shell's own config (GH_EDITOR fallback,
      # git, systemd services...). Fish/nushell additionally pin nvim
      # per-shell; this is the system-wide baseline (issue #95).
      environment.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };

      imports = modules;
    }
  );
}
