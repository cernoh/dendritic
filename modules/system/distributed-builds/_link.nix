# Facts shared by the two halves of the NIXPC build link (issue #209). Both
# modules import this file, so the account name, the key path, the builder
# address, and the builder host key cannot drift apart.
{
  # Account that carries the link: created by builder.nix on the build host,
  # used by client.nix as the login of every remote build.
  user = "remotebuild";

  # Private key of that account, held by root on the machine that ships the
  # builds (ASAHI). The path stays outside the store on purpose:
  # `nix.buildMachines.sshKey` must name a real file, and this repository is
  # public, so only the matching .pub below enters the repo. Install the key
  # once, as root on ASAHI, before the first switch that includes client.nix:
  #   sudo install -o root -g root -m 600 <key> /root/.ssh/remotebuild
  keyPath = "/root/.ssh/remotebuild";

  # Matching public key, committed for the build host's authorized_keys.
  publicKeyFile = ./remotebuild.pub;

  # Build host address: the tailnet IPv4 address of NIXPC, which tailscale
  # keeps stable for the life of the node. Plain names are not usable here:
  # both hosts resolve through the unbound instance of system/network
  # (nameserver 127.0.0.1), and that resolver does not serve the tailnet zone.
  # Verified on 2026-09-16 with `getent hosts` on both machines: `nixpc` and
  # `nixpc.tail49d78b.ts.net` both fail to resolve, while a direct TCP
  # connection to this address on port 22 succeeds from ASAHI.
  hostName = "100.121.170.108";

  # Only aarch64-linux work crosses the link. NIXPC compiles ASAHI's
  # derivations under qemu-aarch64, because nixpcConfiguration.nix registers
  # that platform through boot.binfmt.emulatedSystems.
  system = "aarch64-linux";

  # ed25519 SSH host key of NIXPC: base64 of /etc/ssh/ssh_host_ed25519_key.pub
  # (2026-09-16). Nix base64-decodes this field and uses it as the known_hosts
  # entry of the connection (libstore/ssh.cc, parsePublicHostKey), so the Mac's
  # daemon pins the builder identity instead of trusting an unverified key.
  # Update the value if the host key of NIXPC is ever regenerated.
  publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUwxd1lqRCtEOHBPZkhMQnJnbXQ5K2FXZlpXNHZnL3k3Y1k4blJsNTFIWTggcm9vdEBuaXhvcwo=";
}
