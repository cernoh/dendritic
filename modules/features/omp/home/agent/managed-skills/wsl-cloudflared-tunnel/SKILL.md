---
name: wsl-cloudflared-tunnel
description: Expose local services running in WSL via cloudflared quick tunnel when direct access from Windows fails
---

# Expose WSL Services via Cloudflared Tunnel

When services run in WSL but need to be accessed from Windows (or externally), and direct WSL IP access fails due to networking/firewall issues, use cloudflared quick tunnels.

## Procedure

1. Verify cloudflared is installed: `which cloudflared`
2. Start tunnel in background, redirecting output to log file:
   ```bash
   nohup cloudflared tunnel --url http://localhost:<PORT> > /tmp/cloudflared.log 2>&1 &
   ```
3. Wait ~8 seconds for tunnel establishment, then extract URL:
   ```bash
   grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /tmp/cloudflared.log | head -1
   ```
4. Verify the tunnel works by reading the URL or curling it

## When to Use

- User can't access WSL services from Windows browser via localhost or WSL IP
- WSL networking mode is not mirrored and port forwarding is cumbersome
- Quick temporary access needed without configuring firewall rules

## Notes

- Tunnel URL is temporary and changes each restart
- No uptime guarantee for account-less quick tunnels
- Tunnel runs as long as the cloudflared process is alive
- Check `/tmp/cloudflared.log` for connection status and errors
