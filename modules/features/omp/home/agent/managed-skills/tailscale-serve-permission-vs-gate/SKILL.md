---
name: tailscale-serve-permission-vs-gate
description: "Decide whether a tailscale serve command can even write config: the non-root \"serve config denied\" error and the operator remedy, why --https probes hit the tailnet gate before the permission check (misleading you into thinking you have write access), how --http behaves differently, and why --yes or a PTY cannot satisfy the HTTPS-certificate consent. Use before promising a phone-reachable tailnet URL, or when a serve command fails and you cannot tell a permissions problem from a tailnet-setting problem."
---

Two independent gates block `tailscale serve`. They fire in a fixed order, and the
text of the failure tells you which one you hit. Verified on Tailscale 1.102.3,
NixOS, 2026-09-16.

## Gate 1: the tailnet has no Serve / HTTPS certificates

```
Serve is not enabled on your tailnet.
To enable, visit:

         https://login.tailscale.com/f/serve?node=<node-id>
```

Then the client **blocks** instead of exiting. Facts that save a wasted cycle:

- `--yes` does **not** bypass it. The message is identical with the flag.
- A PTY does **not** turn it into an answerable prompt. Running the command
  under `script -qec` (or any TTY) still just prints the URL — there is no
  `y/n` to send.
- Only a browser **logged in as the tailnet admin** completes it. The equivalent
  admin-console page is `https://login.tailscale.com/admin/dns` →
  **HTTPS Certificates** → **Enable HTTPS**.
- Control-plane signal that it worked: `tailscale status --json` →
  `Self.CertDomains` becomes `["<node>.<tailnet>.ts.net"]`. While it is absent,
  HTTPS is not provisioned and the URL cannot work.
- `MagicDNSEnabled: true` is necessary but **not** sufficient — check
  `CertDomains`, not MagicDNS.

## Gate 2: the local user may not write serve config

```
sending serve config: Access denied: serve config denied

Use 'sudo tailscale serve …'.
To not require root, use 'sudo tailscale set --operator=$USER' once.
```

Root writes fine, as does an operator. A systemd unit runs as root, so a root
unit fails only on gate 1.

## The ordering trap (this is the one that misleads)

For `--https=<port>`, gate 1 is checked **before** the permission check. So a
non-root user probing `--https` sees only the tailnet message and concludes
"serve is allowed here, the tailnet just needs configuring". That conclusion is
unproven — the permission check never ran.

`--http=<port>` behaves differently: it reaches the write step and is denied
with gate 2's message. Evidence that HTTP mode does not require the
HTTPS-certificate consent, which makes it a candidate fallback when the consent
cannot be completed (cost: no PWA install, no background notifications).

To establish capability, probe with a **port you do not need** and read the
error text:

```sh
out=$(timeout -k 5 20 tailscale serve --bg --yes --http=17999 http://127.0.0.1:7930 2>&1); rc=$?
printf 'rc=%s\n%s\n' "$rc" "$out"   # 124 = blocked; gate 1 and gate 2 read differently
```

Always bound the probe with `timeout -k` (SIGKILL fallback). The client ignores
SIGTERM while it waits, so a plain `timeout` can leave a blocked client behind,
and each abandoned probe is another client parked against tailscaled.

## Teardown

`tailscale serve --https=<port> off` is port-scoped and prints
`handler does not exist` when nothing is mapped — that is success, not failure.
Avoid `tailscale serve reset`, which clears every mapping on the node.

Related: `skill://tailscale-serve-unit-stuck` covers the systemd side — the
`Type=oneshot` `TimeoutStartSec=infinity` trap, the SIGTERM-ignoring client, and
the unit diagnosis signals.
