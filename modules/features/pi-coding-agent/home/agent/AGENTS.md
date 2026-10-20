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

`pkgs.pi-coding-agent` is the runtime (`pi` 1.2.0). Extensions may only use pi
APIs that exist in it, so `npm/package.json` holds the install set and its
ranges:

- `pi-agent-browser-native` — unpin OK since 0.87.0 provides
  `ctx.sessionManager.buildSessionProjection()`; 0.9.6 installed and working.
- `@krtclcdy/tersio` — the package ships its OpenCode plugin entry at
  `extensions/server.ts` (default export is a Plugin object, not a pi factory),
  and pi's conventional discovery loads every top-level `extensions/*.ts`, so
  startup aborts with "Extension does not export a valid factory function". The
  package declares no `pi` manifest, so `settings.json` uses the object form with
  `extensions: ["!extensions/server.ts"]` to load the real extension set
  (caveman, pstack, rtk, combo, commands, timing, updater) and skip the plugin
  entry. Drop the filter only when upstream adds a `pi` manifest.

`settings.json` lists packages unversioned, so a bare `pi install npm:<pkg>`
silently un-pins. Update from the repo path instead: bump the range in
`npm/package.json` (or `npm update <pkg>`) and run
`npm install --omit=dev --legacy-peer-deps` in
`modules/features/pi-coding-agent/home/agent/npm`. Do not run
`pi update --extensions`: it calls npm with `--prefix ~/.pi/agent/npm`, and npm
resolves that symlinked path one level deeper every run, appending duplicate
`../../../.config/dendritic/...` package-lock keys (329 were committed before
the 2026-10-15 cleanup, and one `pi update` grew them to 1613). A corrupted
lock also makes `npm audit` report a phantom extraneous `pi-mcp-client`; regen
with `rm package-lock.json node_modules && npm install --omit=dev
--legacy-peer-deps` from the repo path. Peer ranges name pi 0.99 stubs; the real
runtime comes from nix.

## Runtime state in this git-tracked directory

`~/.pi/agent` is an out-of-store symlink into this repo, so anything an extension
writes at runtime lands inside a git-owned directory. Most of it is listed in
`.gitignore`; two entries are credentials and must stay listed.

- **`pi-freeflow-relay-state.json` carries a LIVE secret.** `relays[].auth` is a
  256-bit token the `pi-freeflow` provider presents to the deployed Cloudflare
  worker (`relay-*.zoiny.workers.dev`). It is written the moment a relay is added
  and rotates only when the relay is re-added, so a commit leaks a working
  credential for the life of the relay. Same hazard as `auth.json`, and it is
  ignored for the same reason. Found untracked and unignored on 2026-10-08 during
  the funes push; the token had never been committed, so nothing needed
  rotating — check `git log --all -S<token>` before assuming that again.
- **`auth.json` holds pi provider credentials.** Never read it into a prompt, a
  commit, or an artifact.
- **`pi-sessions/messaging/` is ephemeral IPC, and a live `broker.sock` breaks the flake.**
  Nix's git tree copy cannot hash a unix socket, so while the messaging broker is
  running every `nix eval .#…`, `nix flake check`, and `nixos-rebuild` on this
  checkout fails with `file '…broker.sock' has an unsupported type`. The directory
  is ignored for that reason, not for secrecy: `broker.sock`, `broker.pid`, and
  `broker.log` are all recreated by the running session.
- A credential written here is **not** evidence it was ever exposed. Before
  rotating, prove reachability: `git log --all -S<token> --oneline` and
  `git grep <token>`. An untracked file that was never staged needs a gitignore
  rule, not a rotation.

## pi-lazy-loader and pi-lazy-skill-tool

`@valdo766hi/pi-lazy-skill-tool` (skills lazy-loading) declares a peer range of
pi `>=0.85.1 <0.86.0 || >=1.0.0 <1.1.0`, which excludes our 1.2.0 — installed
anyway via `--legacy-peer-deps` and verified working (2026-10-06 on 0.87.1:
`skill` + `skill_search` tools register, exact-name load returns the real
skill body, `typebox` resolves from pi's own node_modules). It must stay
eager: it hooks `session_start`/`context`/`before_provider_request`. Default
adaptive routing, no `lazy-skill.json` — defaults are the config.

`pi-lazy-loader` is installed but defers **nothing**. Whole-package audit
2026-10-06: every installed package registers LLM-callable tools
(`pi-fff`, `pi-web-access`, `pi-mcp-client`, `pi-background-tasks`, `pi-subagents`,
`pi-agent-browser-native`, `pi-herdr`, `pi-sessions`, `pi-computer-use`,
`rpiv-todo`, `pi-memory`, `bigpowers`, `pi-lazy-skill-tool`), providers (`pi-freeflow`,
`pi-commandcode-provider`, `pi-background-tasks`), `before_agent_start` prompt
hooks (`pi-tool-discipline`, `ponytail`), or session-start TUI panels
(`pi-open-tui`) — all disqualified by the loader's own caveats (tools invisible
to the LLM until activation, missed startup events). The loose extensions in
`extensions/` are likewise hook-driven (`html-artifacts-channel` =
`before_agent_start`, `herdr-*` = `session_start`), so `lazy.json` has no
targets either. Do not add `lazy: true` to a package without re-running this
audit against its whole `node_modules` tree, not just its entry file.

## Herdr background agents

When `HERDR_ENV=1` and I ask for background subagents (research, prototype,
oracle, review, exploration, delegated work):

- Give each one its **own tab in the same workspace (space)**, not a split pane.
  `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --no-focus`
  then `herdr agent start <name> --kind pi --pane <returned-pane-id>`.
- Name the agent and the tab after what it is doing: `research`, `prototype`,
  `oracle`, `review` (`herdr tab rename <tab> <label>`).
- Never spawn background work when not inside herdr; fall back to normal tools.

## funes — recall past sessions before re-deriving them

Every pi session is indexed into a funes memory and published to
`crenoo/funes-memory`, so prior decisions are retrievable instead of
re-derivable. **Reach for recall before you re-derive, guess, or ask the user
something this host already decided.**

- **In pi, call the `recall` tool directly** — the funes pi extension
  (`~/.funes/agents/pi`, registered in `settings.json`) already exposes the whole
  surface: `recall`, `get`, `sessions`, `sketch`, `scan`, `status`. It is bound to
  the remote, so a hit is live for every host and every agent. The skill
  `funes-recall` documents the workflow: load it by name before recalling.
- **CLI form**, for shell work and for any agent that is not pi:
  ```sh
  funes recall "what did we decide about …" --memory crenoo/funes-memory
  ```
  Narrow it with `-k <n>`, `--candidates <n>` (4x `-k` or more turns on the
  cross-encoder rerank), `--type text|thinking|tool_use|tool_result`,
  `--harness <id>`, `--since/--until YYYY-MM-DD`.
- **`funes ask` does not work here** — it only accepts `claude` or `codex`, neither of
  which is installed, and `pi` is not an accepted value. The equivalent is installed as
  a command: `~/.pi/agent/bin/funes-ask-pi "<question>"`, or
  `~/.pi/agent/bin/funes-ask-pi --self-test` to verify the wiring. It recalls, then hands
  the passages to a fresh single-turn pi on the *same* model. Always resolve the `SOURCE:`
  line it prints with `get` before repeating the answer — the child has been observed
  inventing a session id.
- **A recall hit is a pointer, not the answer.** Each hit prints a
  `→ get <session> --from A --to B --memory …` line; call `get` with that exact
  range to read the surrounding turns before you treat a passage as a decision.
- Trigger phrases that mean "search the memory first": *we decided*, *last time*,
  *why did we*, *you said earlier*, *did I already*, or any request to recover an
  earlier rationale, constraint, or rejected alternative.
- **Never run `funes index` by hand.** The extension converts and indexes on every
  `turn_end` and publishes at `session_shutdown`. A manual run competes for the
  memory lock and just logs `another funes memory operation is in progress`.
- **Never run `funes update`.** The binary is pinned by the dendritic flake
  (`modules/features/funes/_funes.pkg.nix`) and lives in the read-only nix store
  behind `/run/current-system/sw/bin/funes`. Bump `pinnedVersion` instead.
- **Secrets are redacted at index time; treat that as the rule, not an obstacle.**
  If a push reports `held back N row(s)`, that is `funes scrub` followed by
  another push — never a blanket allow, and never paste a raw finding into chat.
- A hit may be **wrong**: the index stores what was said, including a conclusion
  later disproved. Check the session date and corroborate before acting on it.
- If background indexing or publishing stops, read
  `~/.funes/agents/pi/scripts/funes-sync.log` before touching anything — it names
  the failing step per turn. `funes status` reports pending embedding and what the
  remote is still missing.