/**
 * Shared loopback bridge for the omp HTML tools.
 *
 * Purpose: one server, one token, one menu for the session. `grill-form.ts`
 * (grill sessions) and `wayfinder-view.ts` (map view) register routes and
 * menu sections here instead of binding their own ports, so the user keeps
 * one tab and scrolls between the map and every grilling session.
 *
 * Contract:
 * - Binds to 127.0.0.1 on an ephemeral port; every route needs the
 *   per-process token. Nothing but the session reads it.
 * - `server.unref()` plus a single `session_shutdown` close: the server never
 *   holds the event loop after the session ends.
 * - Routes dispatch on the first path segment after the token. `""` serves
 *   the menu. Unknown segments are 404.
 * - Menu sections are render callbacks, so grill rounds and wayfinder counts
 *   stay live without the bridge polling anything.
 */
import { randomBytes } from "node:crypto";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { escapeHtml, humanDate, pageShell } from "./html";

export type BridgeHandler = (
  request: IncomingMessage,
  response: ServerResponse,
  url: URL,
  rest: string[],
) => void | Promise<void>;

export interface MenuSection {
  title: string;
  render: () => string;
}

const token = randomBytes(16).toString("hex");
let server: Server | undefined;
let starting: Promise<string> | undefined;
let baseUrl = "";
let shutdownWired = false;

const routes = new Map<string, BridgeHandler>();
const sections = new Map<string, MenuSection>();

export function bridgeToken(): string {
  return token;
}

export function bridgeBase(): string {
  return baseUrl;
}

export function send(response: ServerResponse, status: number, body: string, type = "text/plain; charset=utf-8"): void {
  response.writeHead(status, { "content-type": type, "cache-control": "no-store" });
  response.end(body);
}

export function sendJson(response: ServerResponse, status: number, value: unknown): void {
  send(response, status, JSON.stringify(value), "application/json; charset=utf-8");
}

/** Register (or replace) the handler for one first path segment. */
export function registerRoute(segment: string, handler: BridgeHandler): void {
  routes.set(segment, handler);
}

/** Register (or replace) one menu section. Grill sessions use one id per session. */
export function registerMenuSection(id: string, section: MenuSection): void {
  sections.set(id, section);
}

const MENU_CSS = `.menu { display: grid; gap: 22px; }
.menu-section { background: var(--card); border: 1.5px solid var(--line); border-radius: 10px; padding: 18px 20px; }
.menu-section h2 { margin: 0 0 10px; border: 0; padding: 0; font-size: 18px; }
.menu-section ul { margin: 0; padding-left: 20px; }
.menu-section li { margin: 6px 0; }
.menu-section a { color: var(--accent); text-decoration: none; }
.menu-section a:hover { text-decoration: underline; }
.menu-meta { margin: 4px 0 0; font-size: 13px; color: var(--faint); }
.menu-empty { margin: 0; font-size: 13px; color: var(--faint); }`;

function menuPage(): string {
  const blocks = [...sections.entries()]
    .map(
      ([id, section]) =>
        `<section class="menu-section" id="menu-${escapeHtml(id)}"><h2>${escapeHtml(section.title)}</h2>${section.render()}</section>`,
    )
    .join("\n");
  return pageShell({
    eyebrow: "omp · pages",
    heading: "Session pages",
    sub: "One server: the wayfinder map and every grilling session. Bookmark this tab and scroll.",
    style: MENU_CSS,
    body: `<main class="menu">${blocks || '<p class="menu-empty">Nothing is served yet.</p>'}</main>`,
    footer: ["one bridge", humanDate()],
  });
}

function route(request: IncomingMessage, response: ServerResponse): void {
  const url = new URL(request.url ?? "/", "http://127.0.0.1");
  const segments = url.pathname.split("/").filter(Boolean);
  if (segments[0] !== "g" || segments[1] !== token) {
    send(response, 404, "Not found");
    return;
  }
  const rest = segments.slice(2);
  try {
    if (rest.length === 0) {
      send(response, 200, menuPage(), "text/html; charset=utf-8");
      return;
    }
    const handler = routes.get(rest[0]);
    if (!handler) {
      send(response, 404, "Not found");
      return;
    }
    const result = handler(request, response, url, rest.slice(1));
    if (result instanceof Promise) {
      result.catch((error: unknown) =>
        sendJson(response, 500, { error: error instanceof Error ? error.message : String(error) }),
      );
    }
  } catch (error) {
    sendJson(response, 500, { error: error instanceof Error ? error.message : String(error) });
  }
}

/** Start the shared bridge once per process; resolves the base URL. */
export function startSharedBridge(pi: { on: (event: string, listener: () => void) => void }): Promise<string> {
  if (baseUrl) return Promise.resolve(baseUrl);
  if (starting) return starting;
  const { promise, resolve: resolveBridge, reject: rejectBridge } = Promise.withResolvers<string>();
  const created = createServer(route);
  created.on("error", rejectBridge);
  created.listen(0, "127.0.0.1", () => {
    const address = created.address();
    if (!address || typeof address === "string") {
      rejectBridge(new Error("The shared HTML bridge has no port."));
      return;
    }
    created.unref();
    server = created;
    baseUrl = `http://127.0.0.1:${address.port}/g/${token}`;
    resolveBridge(baseUrl);
  });
  starting = promise;
  if (!shutdownWired) {
    shutdownWired = true;
    pi.on("session_shutdown", () => {
      server?.close();
      server = undefined;
      baseUrl = "";
      starting = undefined;
      routes.clear();
      sections.clear();
      shutdownWired = false;
    });
  }
  return promise;
}
