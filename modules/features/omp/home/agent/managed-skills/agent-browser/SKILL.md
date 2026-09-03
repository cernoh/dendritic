---
name: agent-browser
description: Browser automation CLI for AI agents (Vercel Labs). Use when the user needs to interact with websites — navigating pages, filling forms, clicking buttons, taking screenshots, extracting data, testing web apps, or automating any browser task. Also for MCP-based browser tools in OMP.
---

# agent-browser

Fast native Rust CLI for browser automation via Chrome DevTools Protocol (CDP). Installed as `agent-browser` (v0.36.0) via Nix (`perSystem.packages.agent-browser`, `homeManagerModules.agent-browser`). Exposed to OMP both as a shell CLI and as an MCP stdio server (`agent-browser mcp`).

## MCP tools (preferred in OMP)

OMP spawns `agent-browser mcp` as a stdio server (`mcp.json: agent-browser`). Tools appear as `agent_browser_*` (core profile by default). For full CLI parity, switch args to `["mcp", "--tools", "all"]` or `["mcp", "--tools", "core,network,react"]`.

Profiles: `core` (default, small context), `network`, `state`, `debug`, `tabs`, `react`, `mobile`, `all`.

Example MCP client config (standalone):

```json
{
  "mcpServers": {
    "agent-browser": {
      "command": "agent-browser",
      "args": ["mcp"]
    }
  }
}
```

## CLI — core loop (use in bash tool)

```bash
export AGENT_BROWSER_SESSION="$(agent-browser session id --scope worktree --prefix task)"
agent-browser open https://example.com
agent-browser snapshot -i          # interactive elements only, with @eN refs
agent-browser click @e2
agent-browser fill @e3 "text"
agent-browser snapshot -i          # re-snapshot after any page change
agent-browser screenshot page.png
agent-browser close
```

Refs (`@eN`) are fresh per snapshot and stale after navigation/rerender — always re-snapshot before next interaction.

## Key commands

```bash
agent-browser open <url>              # launch + navigate
agent-browser snapshot -i --json      # machine-readable
agent-browser click @eN / fill @eN / type @eN / press <key>
agent-browser get text @eN / get attr @eN href
agent-browser find role button click --name "Submit"
agent-browser wait --text "Success" / wait --url "**/dashboard"
agent-browser tab new / tab list / tab close
agent-browser screenshot --annotate   # visual labels matching @eN
agent-browser install                 # download Chrome for Testing (first time)
agent-browser install --with-deps     # + system libs (Linux)
```

## Skills (upstream)

For version-pinned detailed workflows, use the CLI-served skills (never this stub):

```bash
agent-browser skills list
agent-browser skills get core            # essential workflows
agent-browser skills get core --full     # full reference
agent-browser skills get electron        # Electron apps (VS Code, Slack...)
agent-browser skills get slack
agent-browser skills get dogfood         # QA / bug hunts
```

Dashboard: `agent-browser dashboard start` (port 4848) for live viewport + activity feed.

## Nix notes

Package: `nix build .#agent-browser` or `nix run .#agent-browser -- open example.com`.
Chrome is fetched via `agent-browser install` to `~/.cache/agent-browser`; on NixOS ensure system libs are present (`install --with-deps` attempts it, but NixOS needs them via other means — chromium package is an alternative). The binary is the prebuilt Rust release from `vercel-labs/agent-browser` v0.36.0.
