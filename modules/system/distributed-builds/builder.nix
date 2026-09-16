# NIXPC as a build host for ASAHI (issue #209). The client half of the link
# lives in client.nix. The shape follows the nix.dev tutorial "Setting up
# distributed builds": an SSH account for the build host, plus that account in
# nix.settings.trusted-users.
#
# The trusted-users entry is what makes a remote build possible. Nix reaches a
# builder over `ssh-ng`, and that protocol runs `nix-daemon --stdio` on the
# build host as the login account (libstore/ssh-store.hh, remoteProgram). The
# account then asks the NIXPC daemon to accept store imports, and the daemon
# allows unsigned imports only from a trusted user.
{
  self,
  ...
}:
let
  link = import ./_link.nix;
in
{
  flake.nixosModules.remoteBuilder =
    {
      ...
    }:
    {
      users.users.${link.user} = {
        isSystemUser = true;
        group = link.user;
        # The account only runs `nix-daemon --stdio` through sshd, so it needs
        # neither a home directory nor a password. SSH key authentication
        # restricts it to the root user of ASAHI.
        useDefaultShell = true;
        openssh.authorizedKeys.keyFiles = [ link.publicKeyFile ];
      };
      users.groups.${link.user} = { };

      nix.settings = {
        trusted-users = [ link.user ];
        # NIXPC accepts build jobs unattended, and a full store would fail
        # them. Collect garbage during a build while free space is low.
        min-free = 10 * 1024 * 1024;
        max-free = 200 * 1024 * 1024;
      };

      systemd.services.nix-daemon.serviceConfig = {
        MemoryAccounting = true;
        # NIXPC is a desktop. Cap the daemon and its builders at 90% of RAM,
        # and raise their OOM score, so the kernel kills a build before it
        # kills the session.
        MemoryMax = "90%";
        OOMScoreAdjust = 500;
      };
    };
}
