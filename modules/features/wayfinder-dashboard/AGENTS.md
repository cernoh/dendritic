# wayfinder-dashboard — Wayfinder Relay

## Purpose
Mobile-first queue for Wayfinder maps, with a live terminal per running ticket so an answer can be typed from the phone. Each configured project owns a Herdr workspace; starting a frontier ticket claims it on GitHub, creates a tab, starts Pi, and submits a one-ticket Wayfinder brief.

## Ownership
- `default.nix` — Deno package, Home Manager user service, and NixOS tailnet publishing.
- `app/server.ts` — responsive web page, JSON API, GitHub frontier queries, Herdr/Pi launch flow, and the pane terminal bridge.
- `app/deno.json` — local format, type-check, and self-test commands.

## Local Contracts
- GitHub remains canonical. The app stores project coordinates, ticket sessions, and grill history only.
- The frontier is the map's open child issues with a `wayfinder:<type>` label, no assignee, and zero open blockers.
- Claim precedes work: `gh issue edit --add-assignee @me` runs before Herdr creates the ticket tab.
- One project maps to one Herdr workspace. One launch creates one tab and one Pi agent in the project's checkout.
- **A launch records a session** (`ticket`, `tabId`, `paneId`, `agent`) in the project, and that record is the only thing that makes a pane reachable. Every pane route resolves through it, so no other pane on the machine can be read or typed into through the app.
- **Slash commands come from the installed pi, not from a list here.** `GET /api/pi/commands` parses `docs/slash-commands.md` from the pi package root, which is two levels above the resolved `bin/pi` (one level lands on `bin/`). The wrapper must therefore carry `pi-coding-agent` in `runtimeInputs`, or `pi` is absent from its PATH and the parse silently falls back to the six-command list. A phone user cannot remember command names; the chips and the sheet come from that route.
- **A chip fills the box and never runs a command by itself.** One tap inserts the text, and Send submits it. A tap that executed `/quit` or `/new` on a mis-tap would lose a session.
- **The terminal input needs `autocapitalize=off`, `autocorrect=off`, and `spellcheck=false`.** Phone keyboards otherwise turn `/model` into `/Model` and pi will not recognise it.
- **A recorded pane must still live in the project's own Herdr space.** `ownedPane` compares the pane id's workspace prefix with the project's `workspaceId` and refuses otherwise, so a pane someone moved to another space stops being drivable. Herdr ids are workspace-qualified (`w9:p6`), which is where the prefix comes from.
- **A closed tab is recoverable.** `POST …/sessions/<ticket>/restart` recreates the tab in the project's space, starts Pi, and resubmits a one-ticket brief *without* re-claiming (the GitHub assignee is still there). The dashboard offers it as **Restart tab in space** wherever a session reads `gone`.
- **The space can be recreated under you.** Closing a project's last tab makes herdr drop the workspace, so `ensureWorkspace` recreates it on the next launch and rewrites the project's `workspaceId`. The session rows follow it.
- **The terminal is the herdr CLI, not a pty bridge:** read with `pane read --source recent-unwrapped`, type with `pane send-text`, special keys with `pane send-keys`, state with `pane list --workspace`. Long lines wrap in CSS instead of resizing the pane, so the phone shows wrapped text, not the desktop column layout.
- **Key input is an allowlist.** `validKey` accepts one modifier from `ctrl|alt|shift` plus a known key name or a single character; everything else is refused before a byte is written. `herdr` validates again on its side.
- **A bodyless DELETE is legal.** The mutation guard demands `application/json` only when the request carries a body, so closing a session needs no headers.
- `pane send-text`, `pane send-keys`, and `tab close` answer with no body: call them through `herdr()`, never `herdrJson()`. Parsing their empty output throws *after* the bytes already landed, which reads as a failed send that actually succeeded.
- The server binds loopback. NIXPC exposes it to the phone only through Tailscale Serve HTTPS.
- Omp compatibility endpoints under `/api/maps` remain best-effort mirrors for grill rounds and answers.
- Theme colors come from `self.scheme`; `app/server.ts` uses system color keywords only as an undeployed fallback.

## Work Guidance
- Keep the app dependency-free. Prefer browser, Deno, `gh`, and `herdr` primitives over a frontend or server framework.
- Use argument arrays with `Deno.Command`; tracker values must never pass through a shell.
- Preserve the mobile one-action path: project → open map → next unblocked ticket → Start in Pi → type into the ticket terminal.
- **The default map is the one with work.** On load the app fetches every open map's frontier and selects the largest; the first map in the API order is often a finished one, which reads as a broken app. The choice is remembered per project in `localStorage`, and switching the dropdown uses the cached frontiers.
- **Give every scrollable control `scroll-margin-top`** that clears the sticky header, or auto-scroll parks it under the header where it cannot be tapped.
- **A grid of cards needs `minmax(0,1fr)`, not `1fr`.** A grid item defaults to `min-width:auto`, so one long `<select>` option (map titles) or one unbreakable URL in a ticket question widens every card past the phone. Pair it with `overflow-wrap:anywhere` on the text classes and `min-width:0` on the items.
- **A backtick inside the page template's CSS comments breaks the file.** The whole page is one TypeScript template literal; use plain quotes in any CSS or HTML comment added there.
- Keep mutating routes JSON-bodied and reject cross-site requests.

## Verification
- `nix-instantiate --parse modules/features/wayfinder-dashboard/default.nix`
- `cd modules/features/wayfinder-dashboard/app && deno fmt --check && deno task check && deno task test`
- `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.systemd.user.services.wayfinder-dashboard.Service.ExecStart --impure`
- Browser QA at 390 × 844 verifies project switching, the queue, the add-project form, and the terminal view. Assert `document.documentElement.scrollWidth === innerWidth`: a clipped card at phone width is the failure this catches.
- Slash commands: `curl -s localhost:8787/api/pi/commands | jq length` must return about 25, not 6. Six means the docs parse fell back, which means `pi` is off the server PATH.
- Bridge QA against a scratch pane: create one workspace, register a session by hand in `projects.json`, then check that read returns its output, `{"text":"…\n"}` submits one line, `{"keys":["enter"]}` submits, a foreign `paneId` is refused, a bad key is refused, and `DELETE …/sessions/<n>` closes the tab. Point the scratch session at a **nonexistent issue number** before using restart, so the Pi session it starts cannot wander into real tracker work. Close the scratch workspace afterwards.
- Same-space guard: register a session whose `paneId` carries another workspace's prefix and confirm the route answers `Pane is not in this project's Herdr space`.

## Child DOX Index
