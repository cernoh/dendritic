# Global instructions

## Session titles in herdr

`extensions/herdr-title-sync.ts` forwards the pi session name to the herdr pane
(`pane.report_metadata`), so tabs show a real title.

- Default: `pi-sessions` `autoTitle` generates the title; this extension only forwards it.
- Opt in to a custom title agent with `~/.pi/agent/settings.json`:

  ```json
  { "herdrTitleSync": { "agent": "title-generator" } }
  ```

  The agent is a pi agent definition at `~/.pi/agent/agents/<name>.md`; its body is
  the system prompt, and its `model` / `thinking` frontmatter override the defaults.
  `agents/title-generator.md` ships as the ready-to-use one.

- The two modes are **exclusive**. With `herdrTitleSync.agent` set, also set
  `sessions.autoTitle.enable` to `false` in the same settings file, otherwise
  `pi-sessions` keeps writing titles and the two race. With autoTitle off, `/title`
  becomes this extension's regenerate-this-session command.
- Scope: pane title only. The extension's single herdr call is
  `pane.report_metadata`; it never renames a tab or a space/workspace.
- Cadence, timeout, token budget, and prompt all come from `sessions.autoTitle.*`
  (`refreshTurns`, `timeoutSecs`, `tokenBudget`, `prompt`).
  `tokenBudget` must cover a verbose model: 64 tokens returns an empty title
  (current setting: 512).
- `/name` pauses automatic retitling, same as `pi-sessions`; `/title` resumes it.
- Self-check: `node ~/.pi/agent/extensions/herdr-title-sync.check.mjs`

## Extension version pins

`pkgs.pi-coding-agent` is the runtime (`pi` 0.86.0). Extensions may only use pi
APIs that exist in it, so `npm/package.json` pins the two that outran it:

- `pi-agent-browser-native` `0.6.17` — 0.7.0+ calls
  `ctx.sessionManager.buildSessionProjection()`, added in pi 0.87.0.
- `pi-mcp-client` `0.10.0` — 0.11.0 calls `pi.getMcpServers()`, added in pi
  0.99.0. On 0.86 the `session_start` handler throws, and every `mcp_tools`
  call then reports `[configuration_invalid]` even with no `mcp.json`.

Unpin only after `pi` itself moves past the floor; `pi-agent-browser-doctor`
checks the browser extension against the installed pi. `settings.json` lists
packages unversioned, so a bare `pi install npm:<pkg>` silently un-pins — bump
`npm/package.json` and reinstall instead (`npm install --legacy-peer-deps`;
peer ranges name pi 0.99 stubs, the real runtime comes from nix).

## Herdr background agents

When `HERDR_ENV=1` and I ask for background subagents (research, prototype,
oracle, review, exploration, delegated work):

- Give each one its **own tab in the same workspace (space)**, not a split pane.
  `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --no-focus`
  then `herdr agent start <name> --kind pi --pane <returned-pane-id>`.
- Name the agent and the tab after what it is doing: `research`, `prototype`,
  `oracle`, `review` (`herdr tab rename <tab> <label>`).
- Never spawn background work when not inside herdr; fall back to normal tools.