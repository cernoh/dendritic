/**
 * m3e-app-rework collector — the fallback harness for the selection round.
 *
 * The session's own bridge (grill_form) is the first choice: it injects the
 * answers into the conversation with no extra process. This server exists for
 * the cases the bridge cannot serve:
 *
 *  - the user supplies the screenshots, which are binary files the bridge
 *    cannot carry, and
 *  - the session has no grill_form tool, or the user opens the page from
 *    another machine on the tailnet.
 *
 * Run it through nix:
 *     nix shell nixpkgs#deno -c deno run -A collector.ts <dir> [--port 8765]
 *
 * <dir> layout (the agent writes selection.html and shots/; the server writes
 * answers.json and manifest.json):
 *     selection.html   the page copied from assets/selection.html
 *     shots/<id>.png   one capture per screen id
 *     answers.json     written on POST /api/submit
 *     manifest.json    written on every capture
 *
 * Routes:
 *     GET  /                   selection.html
 *     GET  /shots/<name>       a capture, with its real content type
 *     GET  /api/state          { shots: [...], answered: bool, answers: {...}|null }
 *     POST /api/shot?name=<id> raw image body -> shots/<id>.png, updates manifest.json
 *     POST /api/submit         the answers JSON -> answers.json, prints M3E-SUBMIT
 *
 * The ledger for this mode sets:
 *     "transport": { "mode": "collector", "submitUrl": "/api/submit", "shotsDir": "<dir>/shots" }
 */
import { dirname, join, relative } from "node:path";

const CONTENT_TYPES: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".webp": "image/webp",
};

const JSON_HEADERS = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };

const scriptDir = dirname(decodeURIComponent(new URL(import.meta.url).pathname));

function parseArgs(args: string[]): { dir: string; port: number } {
  let dir = "";
  let port = 0;
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--port") {
      port = Number(args[index + 1] ?? 0);
      index += 1;
      continue;
    }
    if (arg.startsWith("--port=")) {
      port = Number(arg.slice("--port=".length));
      continue;
    }
    if (!dir) dir = arg;
  }
  return { dir: dir || scriptDir, port: port || 8765 };
}

const { dir, port } = parseArgs(Deno.args);
const shotsDir = join(dir, "shots");
const answersPath = join(dir, "answers.json");
const manifestPath = join(dir, "manifest.json");
await Deno.mkdir(shotsDir, { recursive: true });

async function writeManifest(): Promise<string[]> {
  const names: string[] = [];
  for await (const entry of Deno.readDir(shotsDir)) {
    if (entry.isFile) names.push(entry.name);
  }
  names.sort();
  await Deno.writeTextFile(
    manifestPath,
    JSON.stringify({ updatedAt: new Date().toISOString(), shots: names }, null, 2),
  );
  return names;
}

/** Resolve a URL path inside `<dir>`, and refuse anything that escapes it. */
async function fileUnderRoot(urlPath: string): Promise<string | null> {
  const decoded = decodeURIComponent(urlPath).replace(/^\/+/, "");
  if (!decoded || decoded.includes("..")) return null;
  const target = join(dir, decoded);
  if (relative(dir, target).startsWith("..")) return null;
  try {
    return (await Deno.stat(target)).isFile ? target : null;
  } catch {
    return null;
  }
}

const server = Deno.serve({ hostname: "127.0.0.1", port }, async (request) => {
  const url = new URL(request.url);
  const path = url.pathname;

  if (request.method === "POST" && path === "/api/shot") {
    const name = (url.searchParams.get("name") ?? "").replace(/[^A-Za-z0-9._-]/g, "");
    if (!name) return new Response(JSON.stringify({ ok: false, error: "The request has no screen name." }), { status: 400, headers: JSON_HEADERS });
    const body = new Uint8Array(await request.arrayBuffer());
    if (body.byteLength === 0)
      return new Response(JSON.stringify({ ok: false, error: "The request body is empty." }), { status: 400, headers: JSON_HEADERS });
    const file = `${name}.png`;
    await Deno.writeFile(join(shotsDir, file), body);
    const shots = await writeManifest();
    console.log(`M3E-SHOT ${name} ${body.byteLength} bytes (${shots.length} captures)`);
    return new Response(JSON.stringify({ ok: true, file, bytes: body.byteLength, shots }), { headers: JSON_HEADERS });
  }

  if (request.method === "POST" && path === "/api/submit") {
    const text = await request.text();
    let parsed: unknown;
    try {
      parsed = JSON.parse(text);
    } catch {
      return new Response(JSON.stringify({ ok: false, error: "The body is not JSON." }), { status: 400, headers: JSON_HEADERS });
    }
    await Deno.writeTextFile(answersPath, JSON.stringify(parsed, null, 2));
    const answers = (parsed as { answers?: Record<string, string> }).answers ?? {};
    const decided = Object.values(answers).filter((value) => String(value).trim().length > 0).length;
    console.log(`M3E-SUBMIT ${answersPath} (${decided} decisions answered)`);
    return new Response(JSON.stringify({ ok: true, path: answersPath, decided }), { headers: JSON_HEADERS });
  }

  if (request.method === "GET" && path === "/api/state") {
    const shots = await writeManifest();
    let answers: unknown = null;
    try {
      answers = JSON.parse(await Deno.readTextFile(answersPath));
    } catch {
      answers = null;
    }
    return new Response(JSON.stringify({ ok: true, shots, answered: answers !== null, answers }), { headers: JSON_HEADERS });
  }

  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Not found", { status: 404 });
  }

  const file = await fileUnderRoot(path === "/" ? "selection.html" : path);
  if (!file) return new Response("Not found", { status: 404, headers: { "cache-control": "no-store" } });
  const dot = file.lastIndexOf(".");
  return new Response(await Deno.readFile(file), {
    headers: {
      "content-type": CONTENT_TYPES[file.slice(dot).toLowerCase()] ?? "application/octet-stream",
      "cache-control": "no-store",
    },
  });
});

const address = server.addr as Deno.NetAddr;
console.log(`M3E-COLLECTOR http://127.0.0.1:${address.port}/ dir=${dir}`);
console.log(`M3E-COLLECTOR-ANSWER-ENDPOINT http://127.0.0.1:${address.port}/api/submit`);
