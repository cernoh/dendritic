# funes feature — durable memory for the coding agents on this flake.
#
# funes indexes past agent sessions (Claude Code, Codex, pi, Hermes) into one
# local memory and hands the recall back as MCP tools, so an agent can reach
# its own prior decisions mid-task. The binary is not in nixpkgs; it is a
# prebuilt upstream release asset (see _funes.pkg.nix for why fetch beats a
# source build, and for the bump recipe).
#
# What this feature does and does NOT do:
# - Installs the pinned `funes` binary system-wide, so every agent on the
#   host can read the same memory.
# - Does NOT run `funes add pi` for you, and that is deliberate. Two reasons,
#   both load-bearing:
#     1. `funes add` is interactive. It asks before the first index, offers to
#        create an `<user>/funes-memory` dataset on the Hub, and refuses to run
#        unattended off a terminal. An activation script that calls it would
#        either fail or, worse, silently decline on the user's behalf.
#     2. It writes into pi's own config. `~/.pi/agent` is symlinked
#        out-of-store to modules/features/pi-coding-agent/home/agent, and
#        settings.json there is TRACKED IN GIT. `funes add pi` registering
#        `$FUNES_BIN mcp` would edit a git-owned file from outside the flake,
#        so the next `home-manager` switch would revert it.
#   The integration itself belongs at `~/.funes/agents/pi/`, outside the
#   repo, which is exactly where funes puts it. Run this once, by hand, in a
#   real terminal: `funes add pi`. Then `funes status` reports whether recall
#   is reading your own memory yet.
#
# Secret scanning, and why the push cannot skip it:
# `funes push` refuses to publish unscanned. It looks for `trufflehog` in
# $FUNES_TRUFFLEHOG, then $PATH, then Homebrew and a few fixed dirs, and if it
# finds nothing it errors out with "The secret scan is mandatory - refusing to
# proceed unscanned" BEFORE it writes anything. Sessions are raw transcripts, so
# a token pasted into a chat becomes a published chunk unless a scanner gates
# the push. The feature therefore ships `pkgs.trufflehog` next to `hf`: the
# publish path is unusable without it, exactly like the token login.
#
# Hub sync, and the token that makes it possible:
# funes reads an HF token from $HF_TOKEN, then $HF_TOKEN_PATH, then the stored
# token file at $XDG_CACHE_HOME/huggingface/token (~/.cache/huggingface/token) —
# the last is exactly what `hf auth login` writes. Without the `hf` CLI on
# PATH the user has no way to write that file, and every `funes add <agent>
# <org>/<repo>` / `funes push` prints "staying local". So the feature ships the
# CLI too: one package, and `hf auth login` is the whole setup step.
#
# Opt in from a host or bundle: imports = [ self.nixosModules.funes ];
# attrs/programming imports it, so both hosts get it.
{ self, lib, ... }:
{
  # Overlay: expose the pinned binary as `pkgs.funes` for anyone who wants
  # the overlay rather than the option. The NixOS module below does not depend
  # on it — it resolves `self.packages` directly, the way omp does, so the
  # feature works without desktop having to list another overlay.
  flake.overlays.funes = final: _prev: {
    funes = self.packages.${final.stdenv.hostPlatform.system}.funes;
  };

  flake.nixosModules.funes =
    {
      pkgs,
      ...
    }:
    {
      # A user-facing CLI an agent drives, so it belongs on the system PATH
      # rather than in one home profile: the funes MCP server is spawned by
      # whichever agent is running, and that agent may be a system-level one.
      # `hf` rides along for the same reason: publishing a remote memory is a
      # one-time interactive login, and the agent driving `funes push` has to
      # find the same token the user stored. `trufflehog` rides along because
      # `funes push` hard-refuses to publish without it - the scan is not
      # optional and has no in-binary fallback.
      environment.systemPackages = [
        self.packages.${pkgs.stdenv.hostPlatform.system}.funes
        pkgs.python3Packages.huggingface-hub
        pkgs.trufflehog
      ];
    };

  perSystem =
    { pkgs, ... }:
    let
      funesPkg = pkgs.callPackage ./_funes.pkg.nix { };
    in
    {
      packages.funes = funesPkg;

      apps.funes = {
        type = "app";
        program = "${funesPkg}/bin/funes";
      };
    };
}
