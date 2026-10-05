# Global instructions

## Readable output is HTML, not Markdown

Anything I have to **read and compare** ships as one self-contained HTML file in
`<repo>/artifacts/`, styled with the Marathon industrial-acid theme: specs,
plans, design explorations (N options side by side), code-review writeups,
explainers, status reports, throwaway config editors.

Load the `html-artifacts` skill before writing one. It carries the build
procedure, the exploration-card contract (A/B/C key, tradeoff line, real code,
pros/cons, metrics, picked card), the style contract (no hex outside `:root`),
and the pre-done checks (render it, look at it).

Markdown stays for what an agent reads back: code, task lists, agent briefs,
commit messages, DOX/AGENTS.md files.

**Tracker skills own their own canonical record.** When a skill like
`wayfinder` keeps state on an issue tracker, that state stays Markdown *in the
tracker* — map body, ticket bodies, the Decisions-so-far index. HTML is for
the assets those tickets link out to (prototype pages, research reports,
option comparisons), never a replacement for the record the next session
queries. Add `html-artifacts` to a map's `## Notes` block so every session
working that map gets the theme.

**The channel itself is an extension.** `extensions/html-artifacts-channel.ts`
injects the `artifact_channel` system-prompt section (HTML-first rule,
`frontier.html` for every grilling round, `theme.css` path, `xdg-open` on
handover). It is the only thing that makes HTML the *default* rather than a
strong preference; deleting that one file reverts to Markdown, and the skill
stays usable by hand. Self-check:
`node ~/.pi/agent/extensions/html-artifacts-channel.check.mjs`.

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

`pkgs.pi-coding-agent` is the runtime (`pi` 0.87.1). Extensions may only use pi
APIs that exist in it, so `npm/package.json` pins the one that outran it:

- `pi-agent-browser-native` — unpin OK since 0.87.0 provides
  `ctx.sessionManager.buildSessionProjection()`; 0.8.2 installed and working.
- `pi-mcp-client` `0.10.0` (exact, not `^`) — 0.11.0 calls
  `pi.getMcpServers()`, added in pi
  0.99.0. On 0.86 the `session_start` handler throws, and every `mcp_tools`
  call then reports `[configuration_invalid]` even with no `mcp.json`. That
error is stale extension state: the `session_start` handler threw at boot, so
it persists until Pi is reloaded — downgrading the package is not enough
mid-session.

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