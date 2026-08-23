---
name: herdr-testing
description: Layer local plugin and OMP testing workflows on top of the official Herdr skill.
---

# Herdr plugin testing

Use the official `herdr` skill for CLI safety, `HERDR_ENV=1` requirements, topology, ID parsing, pane I/O, agent waits, and cleanup rules. This skill adds the local-plugin and OMP workflow.

## Link a local plugin

From the plugin checkout:

```bash
herdr plugin link "$PWD"
herdr plugin list --json
herdr plugin action list --plugin PLUGIN_ID
herdr plugin action invoke ACTION_ID --plugin PLUGIN_ID
herdr plugin log list --plugin PLUGIN_ID --limit 20
```

For a manifest pane entrypoint:

```bash
herdr plugin pane open --plugin PLUGIN_ID \
  --entrypoint ENTRYPOINT_ID --placement split \
  --workspace WORKSPACE_ID --no-focus
```

Use `herdr plugin config-dir PLUGIN_ID` for editable `.env` and state files. Herdr-managed environment variables are authoritative; do not override them with `--env`.

After changing the manifest or executable, relink the checkout. Unlink when finished:

```bash
herdr plugin unlink PLUGIN_ID
```

`plugin link` is for local development. Do not use `plugin uninstall` for a linked checkout; uninstall is for Herdr-managed GitHub installs and removes managed files.

## Isolated test workspace

When the user requests a separate test terminal, create one without moving focus:

```bash
response=$(herdr workspace create --cwd "$PWD" --label plugin-test --no-focus)
workspace_id=$(printf '%s\n' "$response" | nu -c 'from json | get result.workspace.workspace_id')
pane_id=$(printf '%s\n' "$response" | nu -c 'from json | get result.root_pane.pane_id')
herdr pane run "$pane_id" 'your-test-command'
herdr pane wait-output "$pane_id" --match 'expected output' --timeout 120000
herdr pane read "$pane_id" --source recent-unwrapped --lines 120
```

Always clean up resources created by this workflow:

```bash
herdr plugin unlink PLUGIN_ID
herdr workspace close "$workspace_id"
```

Do not close workspaces you did not create.

## Drive OMP

Install the integration once:

```bash
herdr integration install omp
```

Start OMP only in an existing available shell pane. Use a unique name and the pane ID returned by the official topology command:

```bash
herdr agent start omp-test --kind omp --pane PANE_ID --timeout 30000
herdr agent prompt omp-test 'Run the plugin test command and report the result.' --wait --timeout 120000
herdr agent read omp-test --source recent-unwrapped --lines 120
```

Use `herdr agent get`, `herdr agent explain --json`, and `herdr agent wait` to inspect lifecycle state. `unknown` is not success; verify actual output. If the OMP integration has a stale SSE session, fully restart OMP before testing again.

## Docker service verification

Run Docker service commands in a Herdr sibling pane with `--no-focus`. Herdr-managed panes use Fish by default, so use Fish-compatible syntax or explicitly invoke `bash -lc` for Bash commands. If Docker credential helper errors report `docker-credential-desktop.exe: exec format error`, use a temporary config when public image pulls need no credentials:

```bash
mkdir -p /tmp/docker-empty
echo '{"auths":{}}' >/tmp/docker-empty/config.json
DOCKER_CONFIG=/tmp/docker-empty docker build -t IMAGE PATH
```

For AgentWebSearch-MCP, verify the live container after rebuilding/recreating:

```bash
docker exec agentwebsearch-mcp python -m py_compile /opt/agentwebsearch/mcp_server.py
timeout 5 curl -i -H 'Accept: text/event-stream' http://127.0.0.1:8902/sse
```

Accept only `HTTP/1.1 200 OK` and an `event: endpoint` payload before the timeout; SSE remains open by design.

## Cleanup

Unlink local plugins and close only workspaces created by the workflow. Do not close user-owned workspaces.
