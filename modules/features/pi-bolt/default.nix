# pi-bolt feature — the same Pi coding agent, compiled ahead of time.
#
# [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt) is `earendil-works/pi`
# built to native code: no Node and no Bun at runtime, ~10x sooner to the first
# prompt, a fraction of the CPU and memory of Pi on Node. It is a drop-in
# second front end, NOT a second configuration: it reads `~/.pi/agent` exactly
# as `pi` does, so sessions, settings, extensions (including the npm package
# set), skills, agents and the `sepia` theme from `features/pi-coding-agent`
# are all shared. Nothing here duplicates that tree — this feature only puts
# the binary on PATH.
#
# Three consequences worth knowing before touching anything:
#
# 1. **Two runtime versions, one config directory.** The pinned release embeds
#    its own Pi build (`pi-bolt --version` reports it, 1.4.0 at the time of
#    writing) which is NOT necessarily the `pkgs.pi-coding-agent` version
#    (1.3.0). Extension peer ranges in ~/.pi/agent/npm were resolved against
#    the nixpkgs Pi, and a newer embedded Pi may rewrite `settings.json` or a
#    store file in a shape the older one does not read. So: run `pi-bolt list`
#    (and `pi-bolt doctor`) after a bump, and if the two disagree, match the
#    versions instead of assuming forward compatibility.
#
# 2. **`pi-bolt update` is not the update path.** It downloads a release into
#    `~/.pi-bolt` and points `~/.local/bin/pi-bolt` at it, which cannot affect
#    the store copy on PATH. `features/pi-bolt/_pi-bolt.pkg.nix` pins the
#    release; the bump is a pin bump there.
#
# 3. **The package must not be "fixed" into a normal ELF.** The executable is a
#    Bun standalone binary that maps its own file; patchelf may rewrite its
#    interpreter but adding an rpath makes it segfault on startup, which is why
#    `bin/pi-bolt` is a wrapper that prepends the glibc search path. The header
#    of `_pi-bolt.pkg.nix` has the full evidence and the alternatives that were
#    ruled out.
#
# Opt in from a host: `modules = [ ... self.nixosModules.pi-bolt ]`.
# `hosts/NIXPC` does exactly that. Do NOT add it to `attrs/programming`: that
# bundle reaches both hosts, and ASAHI runs no coding agents.
{ self, ... }:
{
  # Overlay: expose the pinned binary as `pkgs.pi-bolt` for anyone who wants the
  # overlay rather than the module. The NixOS module below resolves
  # `self.packages` directly, the way funes and omp do, so the feature works
  # without a host having to list another overlay.
  flake.overlays.pi-bolt = final: _prev: {
    pi-bolt = self.packages.${final.stdenv.hostPlatform.system}.pi-bolt;
  };

  flake.nixosModules.pi-bolt =
    { pkgs, ... }:
    {
      # A user-facing CLI an agent may also start (harnesses such as pi-cowboy
      # accept `pi-bolt` as a `harness_type`), so it belongs on the system PATH
      # rather than in one home profile.
      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.pi-bolt ];
    };

  perSystem =
    { pkgs, ... }:
    let
      piBolt = pkgs.callPackage ./_pi-bolt.pkg.nix { };
    in
    {
      packages.pi-bolt = piBolt;

      apps.pi-bolt = {
        type = "app";
        program = "${piBolt}/bin/pi-bolt";
      };
    };
}
