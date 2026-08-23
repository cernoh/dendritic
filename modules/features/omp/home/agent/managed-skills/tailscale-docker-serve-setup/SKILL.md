---
name: tailscale-docker-serve-setup
description: Expose Docker services on your Tailscale network using a sidecar container with tailscale serve
---

# Expose Docker Services via Tailscale

Expose local Docker services on your Tailscale network using a Tailscale sidecar container with `tailscale serve`.

## When to Use
- You have Docker containers running services (web UIs, APIs, etc.)
- You want to access them securely from other devices on your tailnet
- You don't want to expose them to the public internet

## Prerequisites
- Docker installed and running
- Tailscale account with admin access
- Auth key from https://login.tailscale.com/admin/settings/keys

## Setup Procedure

### 1. Create Serve Config (Optional)
For complex setups, create a JSON config file:
```json
{
  "TCP": {
    "8888": {
      "HTTP": true,
      "Handlers": {
        "/": {
          "Proxy": "http://127.0.0.1:8888"
        }
      }
    }
  }
}
```

### 2. Start Tailscale Container
```bash
docker run -d --name tailscale-proxy \
  --network=host \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -v tailscale-state:/var/lib/tailscale \
  -e TS_STATE_DIR=/var/lib/tailscale \
  -e TS_HOSTNAME=my-service \
  -e TS_AUTH_ONCE=true \
  -e TS_AUTHKEY=tskey-auth-... \
  tailscale/tailscale:latest
```

Key flags:
- `--network=host`: Allows reaching services on localhost
- `TS_AUTHKEY`: Required for authentication (generate from admin console)
- `TS_HOSTNAME`: Custom name on tailnet (optional)
- `TS_AUTH_ONCE=true`: Avoid re-auth on restart if state persists

### 3. Configure Serve
Apply serve config for each port:
```bash
docker exec tailscale-proxy tailscale serve --bg --http=8888 http://127.0.0.1:8888
docker exec tailscale-proxy tailscale serve --bg --http=9999 http://127.0.0.1:9999
```

Syntax: `tailscale serve --bg --http=PORT http://127.0.0.1:PORT`

The `--bg` flag makes it persistent across restarts.

### 4. Verify
```bash
docker exec tailscale-proxy tailscale status
docker exec tailscale-proxy tailscale serve status
```

Services are now accessible via:
- Full MagicDNS: `http://hostname.tailnet-name.ts.net:PORT`
- Short hostname: `http://hostname:PORT` (if MagicDNS enabled)

## Troubleshooting

**Auth fails with 502:**
- Interactive login doesn't work in Docker containers
- Always use `TS_AUTHKEY` environment variable
- Generate fresh auth key if previous one was consumed

**Serve config not applying:**
- Apply manually with `tailscale serve` commands instead of `TS_SERVE_CONFIG`
- Check logs: `docker logs tailscale-proxy | grep serve`

**Can't reach localhost services:**
- Ensure container uses `--network=host`
- Verify services are listening on 127.0.0.1 (not just container IPs)

## Example: Hindsight
Exposed two services:
- API (MCP endpoint): port 8888
- Web UI: port 9999

Both accessible at `http://hindsight.tail49d78b.ts.net:8888` and `:9999`
