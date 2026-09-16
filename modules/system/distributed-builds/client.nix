# ASAHI ships its aarch64-linux builds to NIXPC (issue #209). The builder half
# of the link lives in builder.nix; the shape follows the nix.dev tutorial
# "Setting up distributed builds".
{
  self,
  ...
}:
let
  link = import ./_link.nix;
in
{
  flake.nixosModules.distributedBuilds =
    {
      ...
    }:
    {
      nix = {
        # The module writes nix.buildMachines to /etc/nix/machines. Without
        # this switch it also sets the `builders` setting to null, and the
        # daemon then ignores that file.
        distributedBuilds = true;

        # Let NIXPC fetch build inputs from its own substituters. Otherwise
        # the Mac uploads every input path over the link.
        settings.builders-use-substitutes = true;

        buildMachines = [
          {
            hostName = link.hostName;
            # ssh-ng is the protocol of the tutorial, and the option default is
            # the older "ssh".
            protocol = "ssh-ng";
            system = link.system;
            sshUser = link.user;
            sshKey = link.keyPath;
            publicHostKey = link.publicHostKey;
            # One job per physical core: the Ryzen 7 3700X has 8 cores and 16
            # threads, and NIXPC leaves its own `max-jobs` at the nixpkgs
            # default ("auto"). The limit mainly keeps eight emulated jobs
            # from oversubscribing the desktop.
            maxJobs = 8;
            # A builder receives only the derivations whose features it
            # advertises. nixpkgs marks its heaviest packages big-parallel
            # (chromium, qemu, ceph, circt), and the Asahi bootchain belongs
            # to that class. kvm and nixos-test stay out: /dev/kvm cannot
            # accelerate an aarch64 guest on this x86_64 host.
            supportedFeatures = [ "big-parallel" ];
          }
        ];
      };
    };
}
