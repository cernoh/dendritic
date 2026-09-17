/**
 * wayfinder-view — the `wayfinder_view` tool.
 *
 * Purpose: show one wayfinder map as a live HTML page: every ticket grouped by
 * state, with the solved count, the remaining count, and a progress bar, so the
 * human watches a map drain as its tickets resolve.
 *
 * Contract:
 * - The tracker is GitHub. The repo comes from the `repo` argument or from `gh`
 *   in the working directory, and the map is the open issue labelled
 *   `wayfinder:map`.
 * - `gh` is the only data source. Every page request refetches, so the view is
 *   never stale; a short memo keeps two requests in the same instant from
 *   spending the API budget twice.
 * - The bridge server binds to 127.0.0.1 on an ephemeral port, and every route
 *   needs the per-process token. The server holds no timer: the browser polls.
 * - The server handle is unref'd, and `session_shutdown` closes it.
 * - The snapshot under `<agent dir>/html/` carries no token and no script,
 *   because a file must not hold the token that unlocks the bridge.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { createServer, type Server, type ServerResponse } from "node:http";
import { dirname, join } from "node:path";
import { agentDir, escapeHtml, humanDate, openInBrowser, pageShell, safeUrl, slugify, stamp } from "./lib/html";

const TYPE_LABEL = "wayfinder:";
const MEMO_MS = 3000;

interface RawIssue {
  number: number;
  title: string;
  state: string;
  html_url: string;
  body: string | null;
  labels: { name: string }[];
  assignees: { login: string }[] | null;
  pull_request?: unknown;
  issue_dependencies_summary?: { blocked_by?: number };
}

interface Blocker {
  number: number;
  state: string;
}

interface Ticket {
  number: number;
  title: string;
  url: string;
  state: "open" | "closed";
  type: string;
  assignees: string[];
  blockers: Blocker[];
}

interface Counts {
  total: number;
  solved: number;
  open: number;
  takeable: number;
  blocked: number;
  claimed: number;
}

interface MapSections {
  destination: string;
  fog: string[];
  outOfScope: string[];
}

interface MapView {
  repo: string;
  map: { number: number; title: string; url: string } & MapSections;
  tickets: Ticket[];
  counts: Counts;
  byType: { type: string; counts: Counts }[];
}

interface ViewRequest {
  repo?: string;
  map?: number;
  poll: number;
}

function gh(args: string[]): string {
  const result = spawnSync("gh", args, { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (result.error) throw new Error(`gh could not run: ${result.error.message}`);
  if (result.status !== 0) throw new Error((result.stderr || result.stdout || "gh failed").trim());
  return result.stdout;
}

function ghJson<T>(args: string[]): T {
  return JSON.parse(gh(args)) as T;
}

/** The `- ` and `* ` items of a markdown list, without their markers. */
function bulletsOf(text: string): string[] {
  return text
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => /^[-*] /.test(line))
    .map((line) => line.slice(2).trim());
}

/** The `##` sections of a wayfinder map body, their headings lower-cased. */
function mapSections(body: string): MapSections {
  const sections: Record<string, string> = {};
  for (const part of body.split(/^##[ \t]+/m).slice(1)) {
    const newline = part.indexOf("\n");
    const title = (newline < 0 ? part : part.slice(0, newline)).trim().toLowerCase();
    sections[title] = newline < 0 ? "" : part.slice(newline + 1);
  }
  return {
    destination:
      (sections.destination ?? "")
        .split("\n")
        .map((line) => line.trim())
        .find((line) => line.length > 0 && !line.startsWith("<!--")) ?? "",
    fog: bulletsOf(sections["not yet specified"] ?? ""),
    outOfScope: bulletsOf(sections["out of scope"] ?? ""),
  };
}

function count(tickets: Ticket[]): Counts {
  const solved = tickets.filter((ticket) => ticket.state === "closed").length;
  const open = tickets.length - solved;
  const blocked = tickets.filter((ticket) => ticket.state === "open" && ticket.blockers.some((blocker) => blocker.state === "open")).length;
  const claimed = tickets.filter(
    (ticket) => ticket.state === "open" && ticket.assignees.length > 0 && !ticket.blockers.some((blocker) => blocker.state === "open"),
  ).length;
  return { total: tickets.length, solved, open, takeable: open - blocked - claimed, blocked, claimed };
}

function loadView(request: ViewRequest): MapView {
  const repo =
    request.repo?.trim() ||
    ghJson<{ nameWithOwner: string }>(["repo", "view", "--json", "nameWithOwner"]).nameWithOwner;

  const candidates = ghJson<RawIssue[]>(["api", `repos/${repo}/issues?state=all&per_page=100`])
    .filter((issue) => !issue.pull_request && Array.isArray(issue.labels))
    .map((issue) => ({
      issue,
      names: issue.labels.map((label) => label.name).filter((name) => typeof name === "string"),
    }));

  const mapIssue = request.map
    ? candidates.find((entry) => entry.issue.number === request.map)?.issue
    : candidates.find((entry) => entry.issue.state === "open" && entry.names.includes("wayfinder:map"))?.issue;
  if (!mapIssue) {
    throw new Error(
      request.map
        ? `No issue #${request.map} in ${repo}.`
        : `No open issue labelled wayfinder:map in ${repo}. Chart a map first, or pass map: <number>.`,
    );
  }
  if (candidates.length >= 100) {
    throw new Error(`${repo} returns a full page of 100 issues, so the counts would be incomplete.`);
  }

  const tickets: Ticket[] = candidates
    .filter((entry) => entry.issue.number !== mapIssue.number)
    .flatMap((entry) => {
      const type = entry.names
        .filter((name) => name.startsWith(TYPE_LABEL) && name !== `${TYPE_LABEL}map`)
        .map((name) => name.slice(TYPE_LABEL.length))[0];
      if (!type) return [];
      return [
        {
          number: entry.issue.number,
          title: entry.issue.title,
          url: entry.issue.html_url,
          state: entry.issue.state === "closed" ? ("closed" as const) : ("open" as const),
          type,
          assignees: (entry.issue.assignees ?? []).map((assignee) => assignee.login),
          blockers: [],
        },
      ];
    })
    .sort((left, right) => left.number - right.number);

  const blocked = candidates.filter(
    (entry) => entry.issue.issue_dependencies_summary?.blocked_by && tickets.some((ticket) => ticket.number === entry.issue.number),
  );
  for (const entry of blocked) {
    const blockers = ghJson<RawIssue[]>(["api", `repos/${repo}/issues/${entry.issue.number}/dependencies/blocked_by`]);
    const ticket = tickets.find((candidate) => candidate.number === entry.issue.number);
    if (ticket) ticket.blockers = blockers.map((blocker) => ({ number: blocker.number, state: blocker.state }));
  }

  const types = [...new Set(tickets.map((ticket) => ticket.type))].sort();
  return {
    repo,
    map: {
      number: mapIssue.number,
      title: mapIssue.title,
      url: mapIssue.html_url,
      ...mapSections(mapIssue.body ?? ""),
    },
    tickets,
    counts: count(tickets),
    byType: types.map((type) => ({ type, counts: count(tickets.filter((ticket) => ticket.type === type)) })),
  };
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

const VIEW_CSS = `main.wf { display: grid; gap: 28px; }
.wf-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 12px;
}
.wf-stat {
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 14px 16px;
}
.wf-value { margin: 0; font-size: 30px; font-weight: 600; line-height: 1.1; color: var(--ink); }
.wf-label { margin: 2px 0 0; font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--faint); }
.wf-bar { height: 12px; border-radius: 999px; background: var(--line); overflow: hidden; }
.wf-bar span { display: block; height: 100%; background: var(--accent); }
.wf-progress { margin: 8px 0 0; font-size: 13px; color: var(--faint); }
.wf-updated { margin: 0; font-size: 12px; color: var(--faint); }
.wf-destination { margin: 0; font-size: 15px; }
.wf-group h2 { margin: 0 0 8px; font-size: 15px; letter-spacing: 0.02em; }
.wf-group h2 .wf-badge {
  margin-left: 8px;
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--line);
  color: var(--faint);
  font-size: 12px;
  font-weight: 500;
}
.wf-rows { margin: 0; padding: 0; list-style: none; display: grid; gap: 6px; }
.wf-row {
  display: grid;
  grid-template-columns: 56px 1fr auto;
  gap: 10px;
  align-items: baseline;
  padding: 9px 12px;
  background: var(--card);
  border: 1px solid var(--line);
  border-radius: 10px;
}
.wf-row a { color: var(--accent); text-decoration: none; font-variant-numeric: tabular-nums; }
.wf-row a:hover { text-decoration: underline; }
.wf-title { color: var(--ink); }
.wf-meta { font-size: 12px; color: var(--faint); text-align: right; }
.wf-type { font-size: 12px; color: var(--faint); }
.wf-row-note { grid-template-columns: 1fr; }
.wf-empty { margin: 0; font-size: 13px; color: var(--faint); }
.wf-note { margin: 0; font-size: 13px; color: var(--faint); }
@media (max-width: 640px) {
  .wf-row { grid-template-columns: 56px 1fr; }
  .wf-meta { grid-column: 2; text-align: left; }
}`;

function statCards(counts: Counts): string {
  const card = (value: number, label: string) =>
    `<div class="wf-stat"><p class="wf-value">${value}</p><p class="wf-label">${escapeHtml(label)}</p></div>`;
  return `<section class="wf-stats">${card(counts.solved, "solved")}${card(counts.open, "left")}${card(
    counts.takeable,
    "takeable now",
  )}${card(counts.blocked, "blocked")}${card(counts.claimed, "claimed")}${card(counts.total, "tickets")}</section>`;
}

function ticketRow(ticket: Ticket, meta: string): string {
  const parts = [ticket.type, ticket.assignees.length > 0 ? `claimed by ${ticket.assignees.join(", ")}` : "", meta]
    .filter((part) => part.length > 0)
    .join(" · ");
  return `<li class="wf-row"><a href="${escapeHtml(safeUrl(ticket.url))}">#${ticket.number}</a><span class="wf-title">${escapeHtml(
    ticket.title,
  )}</span><span class="wf-meta">${escapeHtml(parts)}</span></li>`;
}

function group(heading: string, tickets: Ticket[], meta: (ticket: Ticket) => string, empty: string): string {
  const rows =
    tickets.length > 0
      ? `<ul class="wf-rows">${tickets.map((ticket) => ticketRow(ticket, meta(ticket))).join("")}</ul>`
      : `<p class="wf-empty">${escapeHtml(empty)}</p>`;
  return `<section class="wf-group"><h2>${escapeHtml(heading)}<span class="wf-badge">${tickets.length}</span></h2>${rows}</section>`;
}

function bulletBlock(heading: string, items: string[]): string {
  if (items.length === 0) return "";
  return `<section class="wf-group"><h2>${escapeHtml(heading)}<span class="wf-badge">${items.length}</span></h2><ul class="wf-rows">${items
    .map((item) => `<li class="wf-row wf-row-note"><span class="wf-title">${escapeHtml(item)}</span></li>`)
    .join("")}</ul></section>`;
}

function renderBody(view: MapView): string {
  const open = view.tickets.filter((ticket) => ticket.state === "open");
  const takeable = open.filter((ticket) => ticket.assignees.length === 0 && !ticket.blockers.some((b) => b.state === "open"));
  const claimed = open.filter((ticket) => ticket.assignees.length > 0 && !ticket.blockers.some((b) => b.state === "open"));
  const blocked = open.filter((ticket) => ticket.blockers.some((b) => b.state === "open"));
  const solved = view.tickets.filter((ticket) => ticket.state === "closed");
  const percent = view.counts.total === 0 ? 0 : Math.round((view.counts.solved * 100) / view.counts.total);

  return `${statCards(view.counts)}
<section>
<div class="wf-bar"><span style="width:${percent}%"></span></div>
<p class="wf-progress">${view.counts.solved} of ${view.counts.total} tickets closed (${percent}%)</p>
</section>
<section class="wf-group"><h2>Destination</h2><p class="wf-destination">${escapeHtml(
    view.map.destination || "The map states no destination yet.",
  )}</p></section>
${group("Takeable now", takeable, () => "", "Nothing unblocked and unclaimed.")}
${group(
    "Blocked",
    blocked,
    (ticket) => `blocked by ${ticket.blockers.map((blocker) => `#${blocker.number} (${blocker.state})`).join(", ")}`,
    "No open ticket waits on another.",
  )}
${group("Claimed", claimed, () => "", "No open ticket is claimed.")}
${group("Solved", solved, () => "", "No ticket is closed yet.")}
${bulletBlock("Not yet specified", view.map.fog)}
${bulletBlock("Out of scope", view.map.outOfScope)}
<section class="wf-group"><h2>By type</h2><p class="wf-note">${view.byType
    .map(
      (entry) =>
        `${escapeHtml(entry.type)}: ${entry.counts.solved} solved, ${entry.counts.open} left`,
    )
    .join(" · ")}</p></section>`;
}

function pollScript(seconds: number): string {
  return `(function () {
  var live = document.getElementById("wf-live");
  var updated = document.getElementById("wf-updated");
  if (!live) return;
  var tick = function () {
    fetch("data.json", { cache: "no-store" })
      .then(function (response) { return response.json(); })
      .then(function (data) {
        live.innerHTML = data.bodyHtml;
        live.dataset.polls = String(Number(live.dataset.polls || "0") + 1);
        if (updated) updated.textContent = "updated " + data.updatedAt;
      })
      .catch(function () {});
    window.setTimeout(tick, ${seconds} * 1000);
  };
  window.setTimeout(tick, ${seconds} * 1000);
})();`;
}

function livePage(view: MapView, pollSeconds: number): string {
  return pageShell({
    eyebrow: `wayfinder · ${view.repo}`,
    heading: view.map.title,
    sub: `map #${view.map.number} · ${view.counts.solved} solved · ${view.counts.open} left`,
    style: VIEW_CSS,
    body: `<p class="wf-updated" id="wf-updated">updated ${escapeHtml(humanDate())}</p><main class="wf" id="wf-live">${renderBody(view)}</main>`,
    script: pollSeconds > 0 ? pollScript(pollSeconds) : undefined,
    footer: [`map #${view.map.number}`, view.repo, pollSeconds > 0 ? `refreshes every ${pollSeconds} s` : "snapshot"],
  });
}

// --------------------------------------------------------------------------
// Tool
// --------------------------------------------------------------------------

export default function wayfinderViewExtension(pi: ExtensionAPI) {
  const z = pi.zod;
  const token = randomBytes(16).toString("hex");
  let request: ViewRequest = { poll: 5 };
  let memo: { at: number; view: MapView } | undefined;
  let server: Server | undefined;
  let starting: Promise<string> | undefined;

  function send(response: ServerResponse, status: number, body: string, type = "text/plain; charset=utf-8"): void {
    response.writeHead(status, { "content-type": type, "cache-control": "no-store" });
    response.end(body);
  }

  function sendJson(response: ServerResponse, status: number, value: unknown): void {
    send(response, status, JSON.stringify(value), "application/json; charset=utf-8");
  }

  /** The view for the open request, refetched unless the memo is fresh. */
  function currentView(): MapView {
    const now = Date.now();
    if (memo && now - memo.at < MEMO_MS) return memo.view;
    const view = loadView(request);
    memo = { at: now, view };
    return view;
  }

  function route(pathname: string, response: ServerResponse): void {
    const segments = pathname.split("/").filter(Boolean);
    if (segments[0] !== "g" || segments[1] !== token) {
      send(response, 404, "Not found");
      return;
    }
    const rest = segments.slice(2);
    try {
      if (rest.length === 0) {
        response.writeHead(302, { location: `/g/${token}/view` });
        response.end();
        return;
      }
      const view = currentView();
      if (rest[0] === "data.json") {
        sendJson(response, 200, { bodyHtml: renderBody(view), updatedAt: humanDate(), counts: view.counts });
        return;
      }
      if (rest[0] === "view") {
        send(response, 200, livePage(view, request.poll), "text/html; charset=utf-8");
        return;
      }
      send(response, 404, "Not found");
    } catch (error) {
      sendJson(response, 500, { error: error instanceof Error ? error.message : String(error) });
    }
  }

  function startBridge(): Promise<string> {
    if (server) return Promise.resolve(`http://127.0.0.1:${(server.address() as { port: number }).port}/g/${token}`);
    if (starting) return starting;
    const { promise, resolve: resolveBridge, reject: rejectBridge } = Promise.withResolvers<string>();
    const created = createServer((incoming, response) => route(new URL(incoming.url ?? "/", "http://127.0.0.1").pathname, response));
    created.on("error", rejectBridge);
    created.listen(0, "127.0.0.1", () => {
      const address = created.address();
      if (!address || typeof address === "string") {
        rejectBridge(new Error("The wayfinder view server has no port."));
        return;
      }
      created.unref();
      server = created;
      resolveBridge(`http://127.0.0.1:${address.port}/g/${token}`);
    });
    starting = promise;
    return promise;
  }

  pi.on("session_shutdown", () => {
    server?.close();
    server = undefined;
    starting = undefined;
  });

  pi.registerTool({
    name: "wayfinder_view",
    label: "Wayfinder View",
    description:
      "Show a wayfinder map as one live HTML page: the solved count, the remaining count, a progress bar, and every ticket " +
      "grouped into takeable, blocked, claimed, and solved. The page refreshes itself in the browser. Call it after charting " +
      "a map and after each ticket resolution. It reads GitHub through `gh` and writes one snapshot file.",
    parameters: z.object({
      repo: z.string().optional().describe("Repository to read, as `owner/name`. Defaults to the repository of the working directory."),
      map: z.number().optional().describe("Map issue number. Defaults to the open issue labelled `wayfinder:map`."),
      poll: z.number().optional().describe("Browser refresh interval in seconds. Default 5. Use 0 for a static page."),
      open: z.boolean().optional().describe("Open the page in the browser. Default true."),
    }),
    loadMode: "essential",
    approval: "write",
    async execute(_toolCallId, params, signal) {
      if (signal?.aborted) return { content: [{ type: "text", text: "Cancelled." }] };

      request = {
        repo: typeof params.repo === "string" && params.repo.trim() ? params.repo.trim() : undefined,
        map: typeof params.map === "number" ? params.map : undefined,
        poll: typeof params.poll === "number" && params.poll >= 0 ? params.poll : 5,
      };
      memo = undefined;

      const view = currentView();
      const snapshot = join(agentDir(), "html", `wayfinder-${slugify(view.repo)}-${stamp()}.html`);
      mkdirSync(dirname(snapshot), { recursive: true });
      writeFileSync(snapshot, livePage(view, 0), "utf8");

      const base = await startBridge();
      if (params.open !== false) openInBrowser(`${base}/view`);

      const counts = view.counts;
      return {
        content: [
          {
            type: "text",
            text:
              `Wayfinder view for ${view.repo}, map #${view.map.number} (${view.map.title}).\n` +
              `${counts.solved} solved, ${counts.open} left, ${counts.takeable} takeable now, ${counts.blocked} blocked, ${counts.claimed} claimed.\n` +
              `Live page: ${base}/view (` +
              (request.poll > 0 ? `the browser refreshes every ${request.poll} s` : "static") +
              `).\n` +
              `Snapshot: ${snapshot}\n` +
              `Report the URL to the user, and keep the session going.`,
          },
        ],
        details: { url: `${base}/view`, snapshot, counts, tickets: view.tickets.length, repo: view.repo, map: view.map.number },
      };
    },
  });
}
