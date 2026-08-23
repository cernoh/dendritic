---
name: agentwebsearch-mcp
description: Use the local AgentWebSearch MCP server for API-key-free web search and page fetching through Chrome CDP
---

# AgentWebSearch MCP

Use the `agentwebsearch` MCP server as the default web-search backend in OMP.

## Tools

- `web_search`: Search Naver, Google, and Brave in parallel.
- `smart_search`: Search and fetch results. Use `depth=simple` for snippets, `medium` for normal research, and `deep` for broad research.
- `fetch_urls`: Fetch and extract page text from selected URLs.
- `get_search_status` and `cancel_search`: Inspect or stop long-running searches.

## Local service

The server runs in Docker at `http://127.0.0.1:8902/sse` with Chromium and three CDP sessions inside the container. Start it with:

```bash
docker build -t agentwebsearch-mcp ~/.omp/agent/managed-skills/agentwebsearch-mcp
docker rm -f agentwebsearch-mcp 2>/dev/null || true
docker run -d --name agentwebsearch-mcp --restart unless-stopped \
  -p 127.0.0.1:8902:8902 agentwebsearch-mcp
```

The Dockerfile build patch is required with current MCP SDK versions: the upstream Starlette SSE handler must import `Response`, return `Response()` after `server.run(...)`, and bind Uvicorn to `0.0.0.0` for the published Docker port. Do not rely on `docker exec` edits; they disappear when the container is recreated.

Verify after rebuilding/recreating:

```bash
python -m py_compile /opt/agentwebsearch/mcp_server.py
timeout 5 curl -i -H 'Accept: text/event-stream' http://127.0.0.1:8902/sse
```

A successful probe returns `HTTP/1.1 200 OK` and an `event: endpoint` payload before timeout because SSE remains open.

OMP loads MCP configuration at startup. Restart OMP after starting or changing the container.
