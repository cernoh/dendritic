# Agent-browser feature — Vercel Labs browser automation CLI for AI agents.
#
# Provides the `agent-browser` binary (native Rust CLI, Chrome via CDP) as a
# Nix package and as an OMP-integrated tool.
#
# Opt in:
#   - Home-manager: `imports = [ self.homeManagerModules.agent-browser ]`
#   - NixOS system: `imports = [ self.nixosModules.agent-browser ]`
#   - Or via `self.nixosModules.programming` (includes it)
#   - Or automatically alongside `omp` via `homeManager` (this flake enables
#     it for the primary user — see modules/system/home-manager/default.nix)
#
# Package is a prebuilt binary fetched from GitHub releases (see
# _agent-browser.pkg.nix for version/hashes).
#
# OMP integration:
#   - Binary is on PATH for `omp`'s bash tool, so agents can run
#     `agent-browser open …`, `snapshot`, `click @eN`, etc.
#   - MCP server is registered in `modules/features/omp/home/agent/mcp.json`
#     as a stdio server (`agent-browser mcp --tools core`) so OMP agents
#     can use `agent_browser_*` tools without shell.
#   - Skill is vendored under `modules/features/omp/home/agent/managed-skills/agent-browser/`
#     (core workflow + `skills get` discovery).
{
  self,
  moduleWithSystem,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.agent-browser = pkgs.callPackage ./_agent-browser.pkg.nix { };
    };

  flake.homeManagerModules.agent-browser = moduleWithSystem (
    { self', ... }:
    {
      home.packages = [ self'.packages.agent-browser ];
    }
  );

  flake.nixosModules.agent-browser = moduleWithSystem (
    { self', ... }:
    {
      environment.systemPackages = [ self'.packages.agent-browser ];
    }
  );
}
