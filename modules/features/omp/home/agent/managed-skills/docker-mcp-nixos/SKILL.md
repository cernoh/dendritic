---
name: docker-mcp-nixos
description: Run Docker MCP servers with persistent browser dependencies on NixOS
---

# Docker MCP Server on NixOS

Use Docker when an MCP server needs FHS libraries or browser dependencies unavailable on NixOS.

## Scrapling browser daemon

```bash
docker rm -f scrapling-mcp 2>/dev/null || true
docker volume create scrapling-playwright-cache
docker run -d --name scrapling-mcp --restart unless-stopped \
  -p 127.0.0.1:8000:8000 \
  -v scrapling-playwright-cache:/root/.cache/ms-playwright \
  pyd4vinci/scrapling mcp --http --host 0.0.0.0 --port 8000
docker exec scrapling-mcp /app/.venv/bin/python -m playwright install --with-deps chromium
```

The container must bind `0.0.0.0`; publish host access on `127.0.0.1:8000`. The named volume preserves Playwright browsers across container recreation.

## Verify

```bash
curl -i -H 'Accept: application/json, text/event-stream' http://127.0.0.1:8000/mcp
docker exec scrapling-mcp test -x /root/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome
```

Then use MCP `fetch` against a JS-rendered page with `network_idle: true`, and MCP `open_session` → `screenshot` → `list_sessions` → `close_session`. Confirm response text contains rendered content, not only the HTML shell. Restart OMP after daemon recovery because MCP configuration is loaded at OMP startup.

Avoid stdio transport for Docker MCP servers; HTTP is more reliable.
