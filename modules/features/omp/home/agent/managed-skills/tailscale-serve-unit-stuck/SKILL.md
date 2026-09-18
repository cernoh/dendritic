---
name: tailscale-serve-unit-stuck
description: "Diagnose and fix a systemd unit that runs tailscale serve but never becomes active: the oneshot TimeoutStartSec=infinity trap, the SIGTERM-ignoring client, the tailnet-level \"Serve is not enabled\" gate that no flag can bypass, and the CertDomains/MagicDNS signals that say whether the phone URL can work yet. Use when a tailnet publish unit sits in activating, when tailscale serve status stays empty after a switch, or before claiming a tailnet-published service is reachable."
---

Companion to `dendritic-tailnet-service-publish` (that skill covers adding a
publisher; this one covers why an existing one never comes up). Verified on
Tailscale 1.102.3 with a NixOS oneshot unit, 2026-09.

## Symptom

The unit stays `activating (start)` and nothing is exposed.
`tailscale serve status` answers `No serve config`. The journal shows:

```
Serve is not enabled on your tailnet.
To enable, visit:
         https://login.tailscale.com/f/serve?node=<NODE_ID>
```

## Cause 1: oneshot units have no start timeout

`Type=oneshot` gets `TimeoutStartSec=infinity` from systemd. A blocked client
therefore never fails, never retries, and never reports anything. Confirm with:

```bash
systemctl show -p TimeoutStartUSec -p SubState -p ExecMainStatus <unit>
# TimeoutStartUSec=infinity, SubState=start, ExecMainStatus=0
```

Fix: bound it explicitly and document why.

```nix
serviceConfig = {
  Type = "oneshot";
  RemainAfterExit = true;
  TimeoutStartSec = "45s";
  TimeoutStopSec = "10s";
  KillSignal = "SIGKILL";   # see Cause 2
  Restart = "on-failure";
  RestartSec = 60;          # low-noise retry; self-heals after the gate opens
};
```

`Restart=on-failure` for a oneshot only engages once the unit actually fails,
so without the deadline the retry policy is dead code.

## Cause 2: the client ignores SIGTERM

While it waits, `tailscale serve` ignores SIGTERM. With default `KillSignal`,
the stop path burns another `TimeoutStopSec` (90s default) before SIGKILL.
Set `KillSignal = "SIGKILL"`. Harmless for a oneshot whose main process has
already exited after a successful start.

## Cause 3: the tailnet gate needs the owner in a browser

Serve is a tailnet-level feature. `--yes` does NOT bypass it: running

```bash
tailscale serve --bg --yes --https=17930 http://127.0.0.1:7930
```

as root and as the login user both print the enable URL and block. Only the
tailnet owner can enable it, at
`https://login.tailscale.com/f/serve?node=<NODE_ID>`. Keep `--yes` anyway, so a
later attempt cannot stop on a prompt.

## Signals to read before blaming the unit

```bash
tailscale status --json
```

- `CurrentTailnet.MagicDNSEnabled` must be `true`, or the phone cannot resolve
  `<host>.<tailnet>.ts.net` and the URL is useless.
- `CurrentTailnet.MagicDNSSuffix` plus `Self.DNSName` give the URL to publish.
- `Self.CertDomains` absent means no HTTPS certificate is provisioned for this
  node yet. It appears once HTTPS/Serve is on. That field is the clearest
  single indicator that the gate is still closed.
- `Self.TailscaleIPs` gives the address for a local probe.

Local name resolution lies: with MagicDNS on, `getent hosts <fqdn>` can still
fail (tailscaled resolver). Probe with
`curl --resolve <fqdn>:<port>:<tailnet-ip>` instead of debugging DNS.

## Proof recipe (no root, no tailnet change)

Commit changes only after proving the bounds with the real client, in a
transient unit:

```bash
systemd-run --user --unit=serve-timeout-test --collect \
  --property=Type=oneshot --property=TimeoutStartSec=10 --property=TimeoutStopSec=5 \
  --property=KillSignal=SIGKILL --property=Restart=on-failure --property=RestartSec=5 \
  "$(command -v tailscale)" serve --bg --yes --https=17930 http://127.0.0.1:7930
sleep 26
systemctl --user show -p ActiveState -p NRestarts serve-timeout-test
journalctl --user -u serve-timeout-test --since "-30s"
systemctl --user stop serve-timeout-test
```

Expected journal lines, which prove the hang is now a bounded failure:

```
start operation timed out. Terminating.
Main process exited, code=killed, status=9/KILL
Failed with result 'timeout'.
Scheduled restart job, restart counter is at 2
```

Use a spare port and stop the unit afterwards; `--collect` removes it.

## Traps

- Do not read the client's exit status through a pipe: with
  `timeout 90 tailscale serve … | head`, `echo $?` reports `head`, and
  `timeout` alone does not escalate to SIGKILL. Use
  `timeout -k 5 25 …` and capture `$?` directly.
- Teardown is port-scoped: `tailscale serve --https=<port> off`. It returns
   rc 0 with `handler does not exist` when nothing is mapped. Never use
  `tailscale serve reset` in an `ExecStop`, because it clears every mapping,
  including ones the user added.
- A blocked client left running from an old unit definition keeps waiting and
  can complete by itself once the gate opens. Check `pgrep -af "tailscale serve"`
  before concluding a mapping was never applied.
