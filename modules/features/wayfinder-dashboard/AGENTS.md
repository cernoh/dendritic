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
- Give every scrollable control `scroll-margin-top` that clears the sticky header, or auto-scroll parks it under the header where it cannot be tapped.
- Keep mutating routes JSON-bodied and reject cross-site requests.

## Verification
- `nix-instantiate --parse modules/features/wayfinder-dashboard/default.nix`
- `cd modules/features/wayfinder-dashboard/app && deno fmt --check && deno task check && deno task test`
- `nix eval .#nixosConfigurations.NIXPC.config.home-manager.users.davr.systemd.user.services.wayfinder-dashboard.Service.ExecStart --impure`
- Browser QA at 390 × 844 verifies project switching, the queue, the add-project form, and the terminal view.
- Bridge QA against a scratch pane: create one workspace, register a session by hand in `projects.json`, then check that read returns its output, `{"text":"…\n"}` submits one line, `{"keys":["enter"]}` submits, a foreign `paneId` is refused, a bad key is refused, and `DELETE …/sessions/<n>` closes the tab. Close the scratch workspace afterwards.

## Child DOX Index
