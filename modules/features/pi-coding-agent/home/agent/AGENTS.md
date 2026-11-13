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

**Tracker skills own their own canonical record.** When a skill like `wayfinder`
keeps state on an issue tracker, that state stays Markdown _in the tracker_ —
map body, ticket bodies, the Decisions-so-far index. HTML is for the assets
those tickets link out to (prototype pages, research reports, option
comparisons), never a replacement for the record the next session queries. Add
`html-artifacts` to a map's `## Notes` block so every session working that map
gets the theme.

**The channel itself is an extension.** `extensions/html-artifacts-channel.ts`
injects the `artifact_channel` system-prompt section (HTML-first rule,
`frontier.html` for every grilling round, `theme.css` path, `xdg-open` on
handover). It is the only thing that makes HTML the _default_ rather than a
strong preference; deleting that one file reverts to Markdown, and the skill
stays usable by hand. Self-check:
`node ~/.pi/agent/extensions/html-artifacts-channel.check.mjs`.

## Session titles in herdr

`extensions/herdr-title-sync.ts` forwards the pi session name to the herdr pane
(`pane.report_metadata`), so tabs show a real title.

- Default: `pi-sessions` `autoTitle` generates the title; this extension only
  forwards it.
- Opt in to a custom title agent with `~/.pi/agent/settings.json`:

  ```json
  { "herdrTitleSync": { "agent": "title-generator" } }
  ```

  The agent is a pi agent definition at `~/.pi/agent/agents/<name>.md`; its body
  is the system prompt, and its `model` / `thinking` frontmatter override the
  defaults. `agents/title-generator.md` ships as the ready-to-use one.

- The two modes are **exclusive**. With `herdrTitleSync.agent` set, also set
  `sessions.autoTitle.enable` to `false` in the same settings file, otherwise
  `pi-sessions` keeps writing titles and the two race. With autoTitle off,
  `/title` becomes this extension's regenerate-this-session command.
- Scope: pane title only. The extension's single herdr call is
  `pane.report_metadata`; it never renames a tab or a space/workspace.
- Cadence, timeout, token budget, and prompt all come from
  `sessions.autoTitle.*` (`refreshTurns`, `timeoutSecs`, `tokenBudget`,
  `prompt`). `tokenBudget` must cover a verbose model: 64 tokens returns an
  empty title (current setting: 512).
- `/name` pauses automatic retitling, same as `pi-sessions`; `/title` resumes
  it.
- **Titles come from a local model.** `agents/title-generator.md` names
  `pi-titler/Qwen3-1.7B-Q4_K_M`, served by the `pi-titler` feature
  (`modules/features/pi-titler`, `nix run .#pi-titler`, `127.0.0.1:8080`).
  `models.json` declares it as a plain OpenAI-compatible provider — not through
  pi's built-in `llama.cpp` provider, which answers `provider_not_found` here in
  every configuration tried, so `--model llama.cpp/…` never resolves. Without
  the server the model is unavailable and `resolveModel` falls through to the
  session's own model, so a title is never lost — it is just paid for again. The
  model id is the router preset's section name, so renaming it in
  `modules/features/pi-titler/default.nix` is a three-file change (`default.nix`,
  `models.json`, the agent's `model:` line). The server must stay resident: a
  title blocked on a cold load eats its own 15 s timeout.
- Self-check: `node ~/.pi/agent/extensions/herdr-title-sync.check.mjs`

## Herdr agent state under Pi-Bolt

Herdr only lets an agent own its pane when it reports under a source/agent pair
that is **hard-coded in the herdr binary** (`full_lifecycle_hook_authority` in
`src/detect/mod.rs`): `("herdr:pi","pi")`, `("herdr:omp","omp")`,
`("herdr:mastracode","mastracode")`, `("herdr:opencode","opencode")`,
`("herdr:kilo","kilo")`, `("herdr:kimi","kimi")`. There is no config key or
plugin hook that adds a pair.

Pi-Bolt's compiled-in reporter identifies as `("pi-bolt","pi-bolt")`, so herdr
keeps screen-scraping the pane with Pi's detection manifest and misreads a
running Pi-Bolt as `blocked` (the `x` in the sidebar), while its session
reference and resume command are ignored.

- `extensions/herdr-pi-bolt-state.ts` reports **the `("herdr:pi","pi")` pair** —
  herdr's own Pi identity — so Pi-Bolt gets the same lifecycle authority `pi`
  gets: reported state wins, screen detection is skipped, and the session is
  recorded with `resume_argv = ["pi-bolt","--session",…]`.
- The file is deliberately **not** named `herdr-agent-state.ts`: Pi-Bolt skips a
  file with that name as "Herdr's Pi integration" and defers to its built-in.
  Its own filename loads everywhere and no-ops unless it detects the Pi-Bolt
  runtime (`process.execPath` matching `pi-bolt`, or `PI_HERDR_NO_SELF_REPORT`),
  so plain `pi` keeps using herdr's integration untouched.
- `settings.json` carries `"extensions": ["-builtin:herdr"]`. That entry turns
  Pi-Bolt's built-in reporter off and is ignored by plain `pi` (no builtin of
  that name). The two cannot coexist: herdr keeps **one** hook authority per
  pane and the last report wins, so a second reporter that is wrong about
  `blocked` would flap both the state and the label.
- Consequence to expect: a Pi-Bolt pane shows agent `pi` in `herdr agent list`
  and the sidebar. The pane title still says `Pi-Bolt - …` (`herdr-title-sync`),
  and `pi-bolt doctor` reports the builtin as `turned off` plus the stale skip
  reason for `herdr-agent-state.ts` — both are correct.
- Takes effect on **new Pi-Bolt processes**. An already-running session keeps
  its loaded built-in reporter until it is restarted.
- Self-check: `node ~/.pi/agent/extensions/herdr-pi-bolt-state.check.mjs`
  (drives the extension against a fake herdr socket: identity, session, resume
  command, state machine, seq ordering, release on quit).

## Herdr-spawned agent children run Pi-Bolt

`herdr_spawn_agent` (pi-herdr) launches a child with
`herdr agent start <name> --kind pi --pane <id> -- <argv>`. Herdr resolves a
kind to ONE **hard-coded canonical executable** and types that literal word into
the pane's shell — `pi` for `--kind pi`. There is no knob:
`herdr agent start
--help` prints "Supported agent kind and canonical
executable", the 0.9.5 config reference has no `[agents.*]` section, and the
kind→`(source, agent)` allowlist in AGENTS.md above is likewise compiled in. So
a fleet child used to run plain `pi` and silently lack `builtin:codemode`,
`builtin:tool-search`, `builtin:mcp`, `builtin:usage` and `builtin:llama.cpp` —
and read `herdr-agent-state.ts` instead of nothing-skipped +
`herdr-pi-bolt-state.ts`.

The only interception point is PATH resolution inside that pane, so:

- **`bin/pi` is a shim** with one gate and two markers:
  - `PI_HERDR_SESSION` — the variable pi-herdr stamps into every pi child pane's
    environment via `pane split --env`, and which nothing else sets. That is the
    `herdr_spawn_agent` path.
  - `PI_HERDR_PI_BOLT=1` — explicit opt-in for a hand-driven agent pane (the
    per-tab background-agent recipe below).

  Either one → `exec pi-bolt`. Neither → `exec` the real
  `/run/current-system/sw/bin/pi` with the same argv, byte for byte: the user's
  shell, scripts, `pi update` and every other pane are untouched, and `exec`
  keeps `process.execPath` real for pi's self-locating code.
- **`~/.local/bin/pi` is a symlink to it**, because that directory is the FIRST
  entry of the session PATH that herdr panes inherit. `~/.pi/agent/bin` is only
  on PATH inside a pi process (pi prepends it), which is too late — the lookup
  happens in the pane's shell, before pi starts. Panes pick the shim up
  immediately; no herdr restart needed.
- That link is declared in `modules/features/pi-coding-agent/default.nix`
  (`home.file.".local/bin/pi".source = ./home/agent/bin/pi`) as a **store
  copy**, so a fresh checkout reproduces it. Two consequences: `git add` the
  shim before the next switch (a flake source copy only carries tracked files,
  so the build fails loudly if you forget), and changing the shim itself needs a
  rebuild. The first switch after the manual `ln -s` leaves a `pi.backup` beside
  it.
- Opt out with `PI_HERDR_PLAIN_PI=1` (force real pi even where the gate would
  fire), or `pi-bolt` / `/run/current-system/sw/bin/pi` by name.
- Failure mode to recognize: if `~/.local/bin/pi` ever goes missing, children
  revert to plain `pi` **silently** — they still work, they just lose the
  compiled-in tooling. That is what `bin/pi --self-check` is for.
- Verified end to end on herdr 0.9.5: a child answering
  `readlink -f
  /proc/$PPID/exe` returns `.../pi-bolt-1.0.3/lib/pi-bolt/pi`,
  and the pane registers as agent `pi` under its spawn name with working→done
  states, a listed pane, and close-on-settle — byte-identical herdr behaviour to
  a plain-`pi` child (A/B tested by disabling the shim), so the shim changes the
  executable and nothing else.

## Extension version pins

`pkgs.pi-coding-agent` is the runtime (`pi` 1.4.0). Extensions may only use pi
APIs that exist in it, so `npm/package.json` holds the install set and its
ranges:

- `cc-my-pi` — Claude-Code-style rendering bundle, replacing `pi-open-tui`. It
  declares its own `pi` manifest (two extension entries plus
  `cc-my-pi-dark.json`), bundles `pi-tasks` and `pi-paster` (so a standalone
  `npm:@tintinweb/pi-tasks` must never be added), and its first load auto-runs a
  setup wizard that writes `settings.json`. 1.4.3 verified loading on pi 1.4.0.
- `pi-agent-browser-native` — unpin OK since 0.87.0 provides
  `ctx.sessionManager.buildSessionProjection()`; currently resolves to 0.9.16.
- `@krtclcdy/tersio` — the package ships its OpenCode plugin entry at
  `extensions/server.ts` (default export is a Plugin object, not a pi factory),
  and pi's conventional discovery loads every top-level `extensions/*.ts`, so
  startup aborts with "Extension does not export a valid factory function". The
  package declares no `pi` manifest, so `settings.json` uses the object form
  with `extensions: ["!extensions/server.ts"]` to load the real extension set
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
the 2026-10-15 cleanup, and one `pi update` grew them to 1613). A corrupted lock
also makes `npm audit` report a phantom extraneous `pi-mcp-client`; regen with
`rm package-lock.json node_modules && npm install --omit=dev
--legacy-peer-deps`
from the repo path. Peer ranges name pi 0.99 stubs; the real runtime comes from
nix.

## Runtime state in this git-tracked directory

`~/.pi/agent` is an out-of-store symlink into this repo, so anything an
extension writes at runtime lands inside a git-owned directory. Most of it is
listed in `.gitignore`; two entries are credentials and must stay listed.

- `extensions/auto-router.routes.json` is durable routing configuration. The
  router's decisions, events, budget stats, latency, and ratings files are
  runtime state and are ignored individually; do not ignore the routes file.
- **`pi-freeflow-relay-state.json` carries a LIVE secret.** `relays[].auth` is a
  256-bit token the `pi-freeflow` provider presents to the deployed Cloudflare
  worker (`relay-*.zoiny.workers.dev`). It is written the moment a relay is
  added and rotates only when the relay is re-added, so a commit leaks a working
  credential for the life of the relay. Same hazard as `auth.json`, and it is
  ignored for the same reason. Found untracked and unignored on 2026-10-08
  during the funes push; the token had never been committed, so nothing needed
  rotating — check `git log --all -S<token>` before assuming that again.
- **`auth.json` holds pi provider credentials.** Never read it into a prompt, a
  commit, or an artifact.
- **`pi-sessions/messaging/` is ephemeral IPC, and a live `broker.sock` breaks
  the flake.** Nix's git tree copy cannot hash a unix socket, so while the
  messaging broker is running every `nix eval .#…`, `nix flake check`, and
  `nixos-rebuild` on this checkout fails with
  `file '…broker.sock' has an unsupported type`. The directory is ignored for
  that reason, not for secrecy: `broker.sock`, `broker.pid`, and `broker.log`
  are all recreated by the running session.
- A credential written here is **not** evidence it was ever exposed. Before
  rotating, prove reachability: `git log --all -S<token> --oneline` and
  `git grep <token>`. An untracked file that was never staged needs a gitignore
  rule, not a rotation.

### Resolving merges in this runtime state

Pi rewrites these files on nearly every session, so a pull conflicts on them
constantly. Resolve by content, never by "ours" or "theirs" as a side:

- `agent/commandcode-models.json`, `agent/pi-freeflow-opencode-version.json`,
  `agent/pi-freeflow-update.json`, `home/cc-my-pi-update-check.json` are
  generated caches — a `checkedAt` stamp plus a provider catalog. The newer
  `checkedAt` wins (usually ours, but read the stamp, not the branch label),
  and a catalog is **never hand-merged**: a union resurrects models the
  provider has dropped, which fails at call time rather than at eval time.
  Re-check the resolved file is valid JSON; a broken cache silently hides
  models instead of breaking a build.
- `home/settings.json` is cc-my-pi's preferences file, and cc-my-pi's first
  load on a config directory without one copies its defaults back as exactly
  `{"ccMyPiSetupDone": true}`. A merge that takes that stub (a branch that
  never had the file) silently drops every rendering setting the live TUI
  reads through `~/.pi`; it is a strict subset of a real file, so keep the
  superset.
- `home/tasks/**` is background-task scratch — the job json and its captured
  output, rewritten by the running session. `home/.gitignore` ignores it, so a
  task pair appearing in a merge diff is upstream noise rather than repo
  content, and it never gets committed back.

## pi-lazy-loader and pi-lazy-skill-tool

`@valdo766hi/pi-lazy-skill-tool` (skills lazy-loading) declares a peer range of
pi `>=0.85.1 <0.86.0 || >=1.0.0 <1.1.0`, which excludes the live runtime (1.4.0
on 2026-10-30, both `/run/current-system/sw/bin/pi` and the build embedded in
`pi-bolt` 1.0.3) — installed anyway via `--legacy-peer-deps` and verified
working on 0.87.1 (2026-10-06: `skill` + `skill_search` tools register,
exact-name load returns the real skill body, `typebox` resolves from pi's own
node_modules). It must stay eager: it hooks
`session_start`/`context`/`before_provider_request`. Default adaptive routing,
no `lazy-skill.json` — defaults are the config.

**Local patch, pi 1.4.0 skew.** Two 1.4 divergences broke `/skill:<name>` (and
`/lazy-skill`, which forwards to it): pi wraps its skill catalog in
`<skills>…</skills>` joined by a single newline, so the extension's exact-anchor
`formatSkillsForPrompt()` rewrite always misses (`failure: "missing"`) and the
compact catalog never applies; and `command.sourceInfo.baseDir` is now the
resource root (`~/.pi/agent`) rather than the skill directory. Because
`handlePromptResult` skipped `publishSnapshot` on that failure, the only
published snapshot stayed the command-registry one from `session_start`, whose
wrong `baseDir` made `guardSkillContext` reject every `/skill:` block by
swapping the whole message for
`[SKILL_UNREADABLE] Skill instructions are unreadable.` (`skill` tool calls kept
working — they read `filePath` and never compare block text.)

The guard compares the block against
`References are relative to ${skill.baseDir}.\n\n${body}`, so the snapshot's
`baseDir` must equal the skill's **own directory** — pi writes the block that
way. Two edits under `npm/node_modules/@valdo766hi/pi-lazy-skill-tool/src/` fix
it: `index.ts` publishes the snapshot before the failure return, and
`slash-command.ts` sets `const baseDir = dirname(sourcePath)`
**unconditionally**. An earlier version of that second edit kept an
`if (command.sourceInfo.baseDir)` override, which silently restored the resource
root and made the fix look applied while `/skill:` stayed broken — do not
reintroduce it.

`npm/patches/pi-lazy-skill-tool.mjs` holds both edits and is wired as
`postinstall`, so the `npm install` / `pi update --extensions` that erases them
(`npm/.gitignore` is `*`, node_modules is not tracked) also re-applies them.
`npm run patch:check` exits nonzero when either is missing, and a missing
upstream anchor warns instead of silently half-patching — re-read the failure
and update the script when upstream changes shape. Drop the patch and the script
once upstream supports 1.4 and the catalog can be compacted again.

Verify with `pi-bolt -p "/skill:wayfinder reply with the first 8 words"`: the
reply must quote the skill body, not report the instructions as unreadable. A
clean session without tools (`--no-tools`) never showed the bug — it takes pi's
append path instead of the anchored replace, so it is not a valid check.

`pi-lazy-loader` is installed but defers **nothing**. Whole-package audit
2026-10-06: every installed package registers LLM-callable tools (`pi-fff`,
`pi-web-access`, `pi-mcp-client`, `pi-background-tasks`, `pi-subagents`,
`pi-agent-browser-native`, `pi-herdr`, `pi-sessions`, `pi-computer-use`,
`rpiv-todo`, `pi-memory`, `bigpowers`, `pi-lazy-skill-tool`), providers
(`pi-freeflow`, `pi-commandcode-provider`, `pi-background-tasks`),
`before_agent_start` prompt hooks (`pi-tool-discipline`, `ponytail`), or
session-start UI panels and session commands (`cc-my-pi`) — all disqualified by
the loader's own caveats (tools invisible to the LLM until activation, missed
startup events). The loose extensions in `extensions/` are likewise hook-driven
(`html-artifacts-channel` = `before_agent_start`, `herdr-*` = `session_start`),
so `lazy.json` has no targets either. Do not add `lazy: true` to a package
without re-running this audit against its whole `node_modules` tree, not just
its entry file.

## pi-vision-tool — `describe_image` for text-only sessions

`pi-vision-tool` adds one tool, `describe_image`: an image plus a free-text
prompt goes to a vision model, the text answer comes back as a tool result, so a
session model without eyes (DeepSeek, most open models) can still read a
screenshot. The **calling** model picks the cost/quality knob per call
(`compress`, `reasoning`, prompt) — there is no per-use configuration.

**The vision model is opencode Go's cheapest image-capable one:
`opencode-go/mimo-v2.6-flash`** — $0.14 input / $0.28 output, $0.0028 cached
read, $60 monthly allowance on Go (≈150k requests a month at the estimate
table's token mix, the highest allowance of any vision model on the plan).
Ordering among models the tool can actually reach: `mimo-v2.6-flash` and
`mimo-v2.5` ($0.14/$0.28) < `glm-5.3-flash` ($0.15/$0.50) <
`deepseek-v4.1-flash` and `minimax-m3.1-flash` ($0.15/$0.60). Reach for
`glm-5.3-flash` when a screenshot read needs more eyes — ~5% more per call.

Cheaper _listed_ prices are traps, not options: `muse-spark-1.2/1.3-contributor`
($0.10/$0.20), `gpt-6-luna`, `claude-haiku-5-5`, `grok-4.7` are served only over
the responses/messages APIs, `qwen3.8-flash` ($0.15/$0.47) only over messages,
and the tool hard-codes `POST {baseUrl}/chat/completions` with an OpenAI body —
it has no provider layer to translate for. That `/chat/completions` is also why
config lives in `~/.pi/agent/vision-tool.json` (tracked, like `settings.json`;
`/vision config …` writes it) and is pointed at a provider whose models pi's own
registry already marks `input: ["text", "image"]`.

**Two opencode quirks break it out of the box**, and
`npm/patches/pi-vision-tool.mjs` fixes both — wired as `postinstall` +
`npm run patch:check`, same pattern as the lazy-skill-tool patch, because
`node_modules` is untracked and every install restores pristine 1.3.7. Follow
any `npm install` with `npm run patch:check`: a dependency-adding run has been
observed to finish without the root postinstall, leaving both patch scripts
unapplied.

- opencode's edge refuses a request with no conversation header —
  `400 MissingSessionID`, "cannot be routed efficiently". Pi's own provider
  sends `x-opencode-session`; the tool's raw `fetch` did not, so every call died
  before the model was reached. The patch adds one id per process (= per pi
  session, which is the granularity the router wants).
- `reasoning_effort` accepts only `none|low|medium|high`, and the tool sends
  pi's level name verbatim, so the default level `off` came back
  `400 Param Incorrect`. The patch maps `off → none` for opencode providers:
  same intent, no reasoning tokens.

Verify end to end (≈$0.0002 of allowance, nothing written to a session):

```sh
pi -nc -ns -np --no-mcp --no-session --mode json \
  --model opencode-go/deepseek-v4.1-flash \
  -p "Call describe_image with image_path=<png>, compress=true, prompt='…'" \
  | grep -o '\"toolName\":\"describe_image\"'
```

A tool execution plus no `Vision tool error` means header, auth lookup and
answer all worked. `pi -ne -e <pkgdir>` isolates the extension from the rest of
the load set when the question is the extension itself. `sharp` compression does
work — its prebuilt `@img/sharp-linux-x64` optional deps install fine even
though npm's allowScripts policy blocks sharp's own install script; pass
`compress: false` when a pixel-level read matters, `reasoning: "medium"` for UI
layout questions.

## pi-auto-router — OpenCode Go off-peak failover

The default model is `auto-router/failover`: Beam Free first at all times;
DeepSeek V4 Pro is the second target during Go Off-Peak, then GPT 6 Luna. During
weekday UTC peak windows the DeepSeek target is excluded, leaving Beam Free then
GPT 6 Luna. Auto-router failover only retries retryable errors before
substantive output begins.

`pi-auto-router` policy times use the Pi process's local clock. The earlier
`extensions/auto-router-utc.ts` package entry sets `TZ=UTC` before the router
loads so the published OpenCode Go schedule stays correct through UK daylight
saving. This affects local-time handling in Pi and its child processes.

The package's stock `exclude-provider` cannot exclude one model when all route
targets share `opencode-go`; `npm/patches/pi-auto-router.mjs` adds
`exclude-target` policy rules for that case. The postinstall and
`npm run patch:check` keep the patch applied. The five auto-router analytics
files are ignored runtime output; keep `auto-router.routes.json` tracked.

## Herdr background agents

When `HERDR_ENV=1` and I ask for background subagents (research, prototype,
oracle, review, exploration, delegated work):

- Give each one its **own tab in the same workspace (space)**, not a split pane.
  `herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$PWD" --no-focus
  --env PI_HERDR_PI_BOLT=1`
  then `herdr agent start <name> --kind pi --pane <returned-pane-id>`. The
  `--env PI_HERDR_PI_BOLT=1` is what makes that pane run **Pi-Bolt** rather than
  plain `pi` (`~/.pi/agent/bin/pi` is the PATH shim; without the marker herdr's
  `--kind pi` canonical executable resolves to the real pi).
- Name the agent and the tab after what it is doing: `research`, `prototype`,
  `oracle`, `review` (`herdr tab rename <tab> <label>`).
- Never spawn background work when not inside herdr; fall back to normal tools.

## funes — recall past sessions before re-deriving them

Every pi session is indexed into a funes memory and published to
`crenoo/funes-memory`, so prior decisions are retrievable instead of
re-derivable. **Reach for recall before you re-derive, guess, or ask the user
something this host already decided.**

- **In pi, call the `recall` tool directly** — the funes pi extension
  (`~/.funes/agents/pi`, registered in `settings.json`) already exposes the
  whole surface: `recall`, `get`, `sessions`, `sketch`, `scan`, `status`. It is
  bound to the remote, so a hit is live for every host and every agent. The
  skill `funes-recall` documents the workflow: load it by name before recalling.
- **CLI form**, for shell work and for any agent that is not pi:
  ```sh
  funes recall "what did we decide about …" --memory crenoo/funes-memory
  ```
  Narrow it with `-k <n>`, `--candidates <n>` (4x `-k` or more turns on the
  cross-encoder rerank), `--type text|thinking|tool_use|tool_result`,
  `--harness <id>`, `--since/--until YYYY-MM-DD`.
- **`funes ask` does not work here** — it only accepts `claude` or `codex`,
  neither of which is installed, and `pi` is not an accepted value. The
  equivalent is installed as a command:
  `~/.pi/agent/bin/funes-ask-pi "<question>"`, or
  `~/.pi/agent/bin/funes-ask-pi --self-test` to verify the wiring. It recalls,
  then hands the passages to a fresh single-turn pi on the _same_ model. Always
  resolve the `SOURCE:` line it prints with `get` before repeating the answer —
  the child has been observed inventing a session id.
- **A recall hit is a pointer, not the answer.** Each hit prints a
  `→ get <session> --from A --to B --memory …` line; call `get` with that exact
  range to read the surrounding turns before you treat a passage as a decision.
- Trigger phrases that mean "search the memory first": _we decided_, _last
  time_, _why did we_, _you said earlier_, _did I already_, or any request to
  recover an earlier rationale, constraint, or rejected alternative.
- **Never run `funes index` by hand.** The extension converts and indexes on
  every `turn_end` and publishes at `session_shutdown`. A manual run competes
  for the memory lock and just logs
  `another funes memory operation is in progress`.
- **Never run `funes update`.** The binary is pinned by the dendritic flake
  (`modules/features/funes/_funes.pkg.nix`) and lives in the read-only nix store
  behind `/run/current-system/sw/bin/funes`. Bump `pinnedVersion` instead.
- **Secrets are redacted at index time; treat that as the rule, not an
  obstacle.** If a push reports `held back N row(s)`, that is `funes scrub`
  followed by another push — never a blanket allow, and never paste a raw
  finding into chat.
- A hit may be **wrong**: the index stores what was said, including a conclusion
  later disproved. Check the session date and corroborate before acting on it.
- If background indexing or publishing stops, read
  `~/.funes/agents/pi/scripts/funes-sync.log` before touching anything — it
  names the failing step per turn. `funes status` reports pending embedding and
  what the remote is still missing.

