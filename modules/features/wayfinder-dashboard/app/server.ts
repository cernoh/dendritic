const PORT = Number(Deno.env.get("PORT") ?? "8787");
const BIND = Deno.env.get("BIND") ?? "127.0.0.1";
const DATA_ROOT = Deno.env.get("DATA_ROOT") ??
  `${Deno.env.get("XDG_STATE_HOME") ?? `${Deno.env.get("HOME")}/.local/state`}/wayfinder-dashboard`;

const theme = {
  primary: Deno.env.get("M3_PRIMARY") ?? "AccentColor",
  onPrimary: Deno.env.get("M3_ON_PRIMARY") ?? "AccentColorText",
  primaryContainer: Deno.env.get("M3_PRIMARY_CONTAINER") ?? "ButtonFace",
  surface: Deno.env.get("M3_SURFACE") ?? "Canvas",
  surfaceVariant: Deno.env.get("M3_SURFACE_VARIANT") ?? "Field",
  base: Deno.env.get("M3_BASE") ?? "Canvas",
  text: Deno.env.get("M3_TEXT") ?? "CanvasText",
  textDim: Deno.env.get("M3_TEXT_DIM") ?? "GrayText",
  outline: Deno.env.get("M3_OUTLINE") ?? "GrayText",
  error: Deno.env.get("M3_ERROR") ?? "Mark",
  success: Deno.env.get("M3_SUCCESS") ?? "AccentColor",
};

interface Session {
  ticket: number;
  title: string;
  url: string;
  type: string;
  map: number;
  tabId: string;
  paneId: string;
  agent: string;
  startedAt: string;
  stopped?: boolean;
}

interface Project {
  id: string;
  name: string;
  repo: string;
  cwd: string;
  workspaceId?: string;
  createdAt: string;
  sessions?: Session[];
}

/** Logical key names herdr accepts; anything else is refused before a byte is written. */
const KEYS = new Set([
  "esc",
  "escape",
  "enter",
  "return",
  "tab",
  "space",
  "backspace",
  "delete",
  "insert",
  "up",
  "down",
  "left",
  "right",
  "home",
  "end",
  "pageup",
  "pagedown",
]);
const MODIFIERS = new Set(["ctrl", "alt", "shift"]);

function validKey(key: string): boolean {
  const parts = key.toLowerCase().split("+");
  const base = parts.pop() ?? "";
  // One modifier at most, from the known set; herdr validates the rest.
  if (parts.length > 1 || parts.some((part) => !MODIFIERS.has(part))) return false;
  if (KEYS.has(base) || base === "k") return true;
  return parts.length === 1 && /^[a-z0-9]$/.test(base);
}

interface Workspace {
  workspace_id: string;
  label: string;
  agent_status: string;
  tab_count: number;
}

interface RawIssue {
  number: number;
  title: string;
  body?: string | null;
  state: string;
  html_url: string;
  labels?: { name: string }[];
  assignees?: { login: string }[];
  issue_dependencies_summary?: { blocked_by?: number };
  sub_issues_summary?: { total: number; completed: number; percent_completed: number };
}

interface Ticket {
  number: number;
  title: string;
  question: string;
  url: string;
  type: string;
}

interface MapEntry {
  id: string;
  repo: string;
  number: number;
  title: string;
  addedAt: string;
}

interface RoundQuestion {
  id: string;
  title: string;
  body?: string;
  recommendation?: string;
  choices?: string[];
}

interface Round {
  number: number;
  title: string;
  intro?: string;
  questions: RoundQuestion[];
  formUrl?: string;
  recordedAt: string;
}

interface AnswerSet {
  round: number;
  answers: { id: string; title: string; answer: string }[];
  extra?: string;
  submittedAt: string;
}

const PROJECTS_FILE = `${DATA_ROOT}/projects.json`;
const MAPS_FILE = `${DATA_ROOT}/registry.json`;
const SETTINGS_FILE = `${DATA_ROOT}/settings.json`;

function safeHistoryPath(id: string, subdir: string): string {
  const safeId = id.replace(/[^A-Za-z0-9_.-]/g, "_");
  return `${DATA_ROOT}/${subdir}/history-${safeId}.json`;
}

async function readJson<T>(path: string, fallback: T): Promise<T> {
  try {
    return JSON.parse(await Deno.readTextFile(path)) as T;
  } catch {
    return fallback;
  }
}

async function writeJson(path: string, value: unknown): Promise<void> {
  await Deno.mkdir(path.slice(0, path.lastIndexOf("/")), { recursive: true });
  const temp = `${path}.${crypto.randomUUID()}.tmp`;
  await Deno.writeTextFile(temp, `${JSON.stringify(value, null, 2)}\n`);
  await Deno.rename(temp, path);
}

async function projects(): Promise<Project[]> {
  return (await readJson<{ projects: Project[] }>(PROJECTS_FILE, { projects: [] })).projects;
}

async function saveProjects(value: Project[]): Promise<void> {
  await writeJson(PROJECTS_FILE, { projects: value });
}

async function settings(): Promise<{ storageSubdir: string }> {
  return await readJson(SETTINGS_FILE, { storageSubdir: "default" });
}

async function history(id: string): Promise<{ rounds: Round[]; answers: AnswerSet[] }> {
  return await readJson(safeHistoryPath(id, (await settings()).storageSubdir), { rounds: [], answers: [] });
}

async function saveHistory(id: string, value: { rounds: Round[]; answers: AnswerSet[] }): Promise<void> {
  await writeJson(safeHistoryPath(id, (await settings()).storageSubdir), value);
}

async function command(name: string, args: string[], cwd?: string): Promise<string> {
  const output = await new Deno.Command(name, { args, cwd, stdout: "piped", stderr: "piped" }).output();
  const text = new TextDecoder().decode(output.stdout);
  if (!output.success) {
    const error = new TextDecoder().decode(output.stderr).trim() || text.trim() || `${name} failed`;
    throw new Error(error);
  }
  return text;
}

async function ghJson<T>(args: string[]): Promise<T> {
  return JSON.parse(await command("gh", args)) as T;
}

async function herdrJson<T>(args: string[]): Promise<T> {
  return JSON.parse(await command("herdr", args)) as T;
}

/** For the herdr commands that answer with no body (`send-text`, `send-keys`, `tab close`). */
async function herdr(args: string[]): Promise<string> {
  return await command("herdr", args);
}

function validRepo(repo: string): boolean {
  return /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/.test(repo);
}

function slug(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 20) || "project";
}

function questionOf(body = ""): string {
  const match = body.match(/^##\s+Question\s*\n([\s\S]*?)(?=^##\s|$)/mi);
  return (match?.[1] ?? body).trim().replace(/\s+/g, " ").slice(0, 500);
}

function frontierOf(issues: RawIssue[]): Ticket[] {
  return issues
    .filter((issue) => issue.state === "open")
    .filter((issue) => (issue.assignees?.length ?? 0) === 0)
    .filter((issue) => (issue.issue_dependencies_summary?.blocked_by ?? 0) === 0)
    .flatMap((issue) => {
      const label = issue.labels?.map((entry) => entry.name).find((name) =>
        name.startsWith("wayfinder:") && name !== "wayfinder:map"
      );
      if (!label) return [];
      return [{
        number: issue.number,
        title: issue.title,
        question: questionOf(issue.body ?? ""),
        url: issue.html_url,
        type: label.slice("wayfinder:".length),
      }];
    })
    .sort((left, right) => left.number - right.number);
}

async function listWorkspaces(): Promise<Workspace[]> {
  const response = await herdrJson<{ result: { workspaces: Workspace[] } }>(["workspace", "list"]);
  return response.result.workspaces;
}

async function ensureWorkspace(project: Project): Promise<string> {
  if (project.workspaceId) {
    try {
      await herdrJson(["workspace", "get", project.workspaceId]);
      return project.workspaceId;
    } catch {
      // The stored Herdr server was reset. Recreate the project space below.
    }
  }
  const response = await herdrJson<{ result: { workspace: { workspace_id: string } } }>([
    "workspace",
    "create",
    "--cwd",
    project.cwd,
    "--label",
    project.name,
    "--no-focus",
  ]);
  project.workspaceId = response.result.workspace.workspace_id;
  const all = await projects();
  const index = all.findIndex((entry) => entry.id === project.id);
  if (index >= 0) {
    all[index] = project;
    await saveProjects(all);
  }
  return project.workspaceId;
}

async function mapsFor(repo: string): Promise<RawIssue[]> {
  return await ghJson([
    "api",
    `repos/${repo}/issues?labels=wayfinder%3Amap&state=all&per_page=100`,
  ]);
}

async function frontier(repo: string, map: number): Promise<Ticket[]> {
  const children = await ghJson<RawIssue[]>([
    "api",
    `repos/${repo}/issues/${map}/sub_issues?per_page=100`,
  ]);
  return frontierOf(children);
}

async function startTicket(
  project: Project,
  map: RawIssue,
  ticket: Ticket,
): Promise<Session> {
  await command("gh", [
    "issue",
    "edit",
    String(ticket.number),
    "--repo",
    project.repo,
    "--add-assignee",
    "@me",
  ]);

  const workspaceId = await ensureWorkspace(project);
  const tabResponse = await herdrJson<{
    result: { tab: { tab_id: string }; root_pane: { pane_id: string } };
  }>([
    "tab",
    "create",
    "--workspace",
    workspaceId,
    "--cwd",
    project.cwd,
    "--label",
    ticket.title.slice(0, 48),
    "--no-focus",
  ]);
  const tabId = tabResponse.result.tab.tab_id;
  const paneId = tabResponse.result.root_pane.pane_id;
  const agent = `wf${ticket.number}-${slug(project.name).slice(0, 12)}-${crypto.randomUUID().slice(0, 4)}`;

  await herdrJson(["agent", "start", agent, "--kind", "pi", "--pane", paneId, "--timeout", "120000"]);
  const prompt = [
    "Use the wayfinder skill to work through exactly one ticket.",
    `Map: ${map.title} (${map.html_url})`,
    `Ticket: ${ticket.title} (${ticket.url})`,
    "The dashboard already claimed the ticket for the authenticated GitHub user.",
    "Load the map at low resolution first, follow its Notes, then resolve this ticket.",
    "Record the resolution on the ticket, close it, update Decisions so far, and surface any newly visible fog.",
    "Do not resolve a second ticket in this session.",
  ].join("\n");
  await herdrJson(["agent", "prompt", agent, prompt]);

  const session: Session = {
    ticket: ticket.number,
    title: ticket.title,
    url: ticket.url,
    type: ticket.type,
    map: map.number,
    tabId,
    paneId,
    agent,
    startedAt: new Date().toISOString(),
  };
  const all = await projects();
  const entry = all.find((candidate) => candidate.id === project.id);
  if (entry) {
    entry.sessions = [...(entry.sessions ?? []).filter((old) => old.ticket !== ticket.number), session];
    await saveProjects(all);
  }
  return session;
}

/** The live pane table for one workspace, keyed by pane id. */
async function paneStates(workspaceId?: string): Promise<Map<string, string>> {
  const states = new Map<string, string>();
  if (!workspaceId) return states;
  const response = await herdrJson<{
    result: { panes: { pane_id: string; agent_status?: string }[] };
  }>(["pane", "list", "--workspace", workspaceId]);
  for (const pane of response.result.panes) {
    states.set(pane.pane_id, pane.agent_status ?? "unknown");
  }
  return states;
}

/** Sessions of one project, with live state; a vanished pane reads `gone`. */
async function sessionsOf(project: Project): Promise<(Session & { agentStatus: string })[]> {
  let states = new Map<string, string>();
  try {
    states = await paneStates(project.workspaceId);
  } catch {
    // Herdr offline: every session then reads `gone` below.
  }
  return (project.sessions ?? []).map((session) => ({
    ...session,
    agentStatus: session.stopped ? "gone" : (states.get(session.paneId) ?? "gone"),
  }));
}

/** A pane this project's own sessions registered, so no other pane on the machine is reachable. */
async function ownedPane(projectId: string, paneId: string): Promise<Session> {
  const project = (await projects()).find((entry) => entry.id === projectId);
  const session = project?.sessions?.find((entry) => entry.paneId === paneId);
  if (!session) throw new Error("Pane not registered for this project");
  // A recorded session is not enough: the pane must still live in this project's
  // own Herdr space. Without this a pane someone moved elsewhere would stay
  // drivable after the project moved on.
  if (project?.workspaceId && workspaceOf(paneId) !== project.workspaceId) {
    throw new Error("Pane is not in this project's Herdr space");
  }
  return session;
}

function workspaceOf(paneId: string): string {
  // Herdr ids are workspace-qualified (`w9:p6`), so the prefix is the workspace.
  return paneId.split(":")[0] ?? "";
}

/** Recreate a closed ticket tab in the project's own space, without re-claiming. */
async function restartSession(project: Project, session: Session): Promise<Session> {
  const workspaceId = await ensureWorkspace(project);
  const tabResponse = await herdrJson<{
    result: { tab: { tab_id: string }; root_pane: { pane_id: string } };
  }>([
    "tab",
    "create",
    "--workspace",
    workspaceId,
    "--cwd",
    project.cwd,
    "--label",
    session.title.slice(0, 48),
    "--no-focus",
  ]);
  const agent = `wf${session.ticket}-${slug(project.name).slice(0, 12)}-${crypto.randomUUID().slice(0, 4)}`;
  await herdrJson([
    "agent",
    "start",
    agent,
    "--kind",
    "pi",
    "--pane",
    tabResponse.result.root_pane.pane_id,
    "--timeout",
    "120000",
  ]);
  await herdrJson([
    "agent",
    "prompt",
    agent,
    [
      "Use the wayfinder skill to work through exactly one ticket.",
      `Ticket: ${session.title} (${session.url})`,
      "This ticket is already claimed for the authenticated GitHub user and its tab was recreated.",
      "Reload the ticket and the map at low resolution, then resolve this ticket only.",
      "Record the resolution, close it, update Decisions so far, and surface any newly visible fog.",
    ].join("\n"),
  ]);
  const revived: Session = {
    ...session,
    tabId: tabResponse.result.tab.tab_id,
    paneId: tabResponse.result.root_pane.pane_id,
    agent,
    startedAt: new Date().toISOString(),
    stopped: false,
  };
  const all = await projects();
  const entry = all.find((candidate) => candidate.id === project.id);
  if (entry) {
    entry.sessions = [
      ...(entry.sessions ?? []).filter((old) => old.ticket !== session.ticket),
      revived,
    ];
    await saveProjects(all);
  }
  return revived;
}

async function paneText(session: Session, lines: number): Promise<{ text: string; agentStatus: string }> {
  const states = await paneStates(workspaceOf(session.paneId));
  return {
    text: await command("herdr", [
      "pane",
      "read",
      session.paneId,
      "--source",
      "recent-unwrapped",
      "--lines",
      String(lines),
      "--format",
      "text",
    ]),
    agentStatus: states.get(session.paneId) ?? "unknown",
  };
}

function page(): string {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="${theme.base}">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<title>Wayfinder Relay</title>
<style>
:root{color-scheme:dark;--primary:${theme.primary};--on-primary:${theme.onPrimary};--primary-container:${theme.primaryContainer};--surface:${theme.surface};--surface-2:${theme.surfaceVariant};--base:${theme.base};--text:${theme.text};--dim:${theme.textDim};--line:${theme.outline};--error:${theme.error};--success:${theme.success};--safe-bottom:env(safe-area-inset-bottom,0px)}
*{box-sizing:border-box}html{background:var(--base)}body{margin:0;background:var(--base);color:var(--text);font:15px/1.45 system-ui,-apple-system,sans-serif;min-height:100dvh}
button,input,select{font:inherit}button{touch-action:manipulation}.shell{max-width:860px;margin:0 auto;padding:0 16px calc(28px + var(--safe-bottom))}
header{position:sticky;top:0;z-index:10;margin:0 -16px;padding:calc(12px + env(safe-area-inset-top,0px)) 16px 12px;background:color-mix(in srgb,var(--base) 92%,transparent);backdrop-filter:blur(14px);border-bottom:1px solid var(--line)}
.brand{display:flex;align-items:center;justify-content:space-between;gap:12px}.brand h1{font-size:18px;letter-spacing:.04em;margin:0}.signal{font-size:12px;color:var(--dim);display:flex;align-items:center;gap:7px}.signal:before{content:"";width:8px;height:8px;border-radius:50%;background:var(--success)}
.project-strip{display:flex;gap:8px;overflow-x:auto;scrollbar-width:none;padding:12px 0 2px}.project-strip::-webkit-scrollbar{display:none}.chip{flex:0 0 auto;min-height:42px;padding:8px 14px;border:1px solid var(--line);border-radius:999px;background:var(--surface);color:var(--text)}.chip.active{background:var(--primary-container);border-color:var(--primary);color:var(--text)}
/* minmax(0,1fr), not 1fr: a grid item defaults to min-width:auto, so one long
   select option (the map titles) would widen every card past the phone width. */
main{display:grid;grid-template-columns:minmax(0,1fr);gap:14px;padding-top:14px;scroll-margin-top:120px}.card{background:var(--surface);border:1px solid var(--line);border-radius:18px;padding:16px;box-shadow:0 12px 28px color-mix(in srgb,var(--base) 45%,transparent);scroll-margin-top:130px;min-width:0}
.eyebrow{margin:0 0 6px;color:var(--primary);font-size:11px;font-weight:750;letter-spacing:.12em;text-transform:uppercase}.muted{color:var(--dim)}h2,h3,p{margin-top:0}h2{font-size:22px;line-height:1.15;margin-bottom:8px}h3{font-size:16px;margin-bottom:5px}.row{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.row.between{justify-content:space-between}.grow{flex:1}
select,input{min-width:0;width:100%;max-width:100%;min-height:48px;border:1px solid var(--line);border-radius:12px;background:var(--surface-2);color:var(--text);padding:10px 12px}label{display:grid;gap:5px;color:var(--dim);font-size:12px;min-width:0}.fields{display:grid;gap:10px;min-width:0}.button{display:inline-flex;align-items:center;justify-content:center;min-height:48px;padding:10px 17px;border:0;border-radius:14px;background:var(--primary);color:var(--on-primary);font-weight:750;text-decoration:none}.button.secondary{background:transparent;color:var(--primary);border:1px solid var(--line)}.button.danger{color:var(--error)}.button:disabled{opacity:.5}.button.wide{width:100%;min-height:56px}
.metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.metric{padding:10px;border-radius:12px;background:var(--surface-2)}.metric strong{display:block;font-size:22px}.metric span{font-size:11px;color:var(--dim);text-transform:uppercase;letter-spacing:.07em}
.ticket{display:grid;gap:12px;min-width:0}.ticket>*{min-width:0}.ticket.primary{border-color:var(--primary);background:linear-gradient(145deg,var(--surface),color-mix(in srgb,var(--primary-container) 30%,var(--surface)))}.ticket-meta{display:flex;gap:7px;align-items:center;color:var(--dim);font-size:12px}.badge{padding:3px 8px;border-radius:999px;background:var(--surface-2);border:1px solid var(--line);text-transform:uppercase;letter-spacing:.06em}.question{margin:0;color:var(--dim)}
/* Ticket questions quote branch URLs and file paths, which have no spaces to
   break on: without this one long URL sets the whole card's min-content. */
.question,h2,h3,.muted,.ticket-meta{overflow-wrap:anywhere}.queue{display:grid;grid-template-columns:minmax(0,1fr);gap:10px}.queue .ticket{padding:14px;border-radius:14px;background:var(--surface-2);border:1px solid var(--line);min-width:0}
details summary{cursor:pointer;min-height:44px;display:flex;align-items:center;font-weight:700}details[open] summary{margin-bottom:12px}.empty{text-align:center;padding:28px 14px}.empty strong{display:block;font-size:18px;margin-bottom:6px}
.toast{position:fixed;left:16px;right:16px;bottom:calc(16px + var(--safe-bottom));z-index:20;max-width:620px;margin:auto;padding:13px 16px;border-radius:14px;background:var(--text);color:var(--base);box-shadow:0 16px 40px color-mix(in srgb,var(--base) 65%,transparent);transform:translateY(140%);transition:transform .25s ease}.toast.show{transform:translateY(0)}.toast.error{background:var(--error);color:var(--base)}
.skeleton{height:90px;border-radius:14px;background:linear-gradient(90deg,var(--surface),var(--surface-2),var(--surface));background-size:200% 100%;animation:pulse 1.2s infinite}@keyframes pulse{to{background-position:-200% 0}}
.live{border:1px solid var(--line);border-radius:14px;background:var(--base);overflow:hidden}
.live .bar{display:flex;gap:6px;align-items:center;padding:9px 11px;border-bottom:1px solid var(--line);flex-wrap:wrap}
.dot{width:9px;height:9px;border-radius:50%;background:var(--dim);flex:0 0 auto}.dot.working{background:var(--primary);animation:blink 1.1s infinite}.dot.idle{background:var(--success)}.dot.blocked{background:var(--error)}@keyframes blink{50%{opacity:.25}}
.term{margin:0;padding:12px;height:min(52vh,440px);overflow:auto;white-space:pre-wrap;overflow-wrap:anywhere;font:12.5px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;color:var(--text);-webkit-overflow-scrolling:touch}
.keys{display:flex;gap:6px;flex-wrap:wrap;padding:0 11px 11px}.key{min-width:44px;min-height:40px;padding:6px 11px;border:1px solid var(--line);border-radius:10px;background:var(--surface-2);color:var(--text);font:600 13px ui-monospace,monospace}
.composer{display:grid;gap:8px;padding:0 11px 11px}.composer textarea{min-height:74px;max-height:34vh;resize:vertical;border:1px solid var(--line);border-radius:12px;background:var(--surface-2);color:var(--text);padding:11px;font:16px/1.45 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
@media(min-width:700px){.fields{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}.fields label:last-child{grid-column:1/-1}.queue{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}.shell{padding-left:24px;padding-right:24px}header{margin-left:-24px;margin-right:-24px;padding-left:24px;padding-right:24px}}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important;animation:none!important;transition:none!important}}
</style></head><body><div class="shell">
<header><div class="brand"><div><p class="eyebrow">Herdr × Pi</p><h1>Wayfinder Relay</h1></div><span class="signal" id="signal">ready</span></div><nav class="project-strip" id="projects" aria-label="Project spaces"></nav></header>
<main id="main"><div class="skeleton"></div><div class="skeleton"></div></main>
</div><div class="toast" id="toast" role="status" aria-live="polite"></div>
<script>
const state={projects:[],project:null,maps:[],map:null,tickets:[],sessions:[],session:null,poll:0,frontiers:{}};
const $=id=>document.getElementById(id);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
async function api(path,options){const r=await fetch(path,{...options,headers:{"content-type":"application/json",...(options&&options.headers)}});const text=await r.text();let value;try{value=JSON.parse(text)}catch{value={error:text}}if(!r.ok)throw new Error(value.error||text||"Request failed");return value}
function toast(message,error=false){const el=$("toast");el.textContent=message;el.className="toast show"+(error?" error":"");clearTimeout(toast.timer);toast.timer=setTimeout(()=>el.className="toast",4500)}
function renderProjectStrip(){const nav=$("projects");nav.innerHTML=state.projects.map(p=>'<button class="chip '+(state.project&&p.id===state.project.id?'active':'')+'" data-project="'+esc(p.id)+'">'+esc(p.name)+'</button>').join('')+'<button class="chip" data-add="1">＋ Project</button>';nav.querySelectorAll('[data-project]').forEach(b=>b.onclick=()=>selectProject(b.dataset.project));nav.querySelector('[data-add]').onclick=()=>{renderAdd();scrollTo({top:0,behavior:'smooth'})}}
function renderAdd(){state.project=null;renderProjectStrip();$("main").innerHTML='<section class="card"><p class="eyebrow">New project space</p><h2>Connect a Wayfinder repo</h2><p class="muted">Relay gives the project its own Herdr space. Starting a ticket claims it, opens a tab, launches Pi, and sends the Wayfinder brief.</p><form id="addForm" class="fields"><label>Project name<input name="name" required autocomplete="off" placeholder="Moon Down"></label><label>GitHub repo<input name="repo" required autocomplete="off" placeholder="owner/repo"></label><label>Local checkout<input name="cwd" required autocomplete="off" placeholder="/home/me/src/project"></label><button class="button wide" type="submit">Create project space</button></form></section>';$("addForm").onsubmit=addProject}
async function addProject(event){event.preventDefault();const button=event.target.querySelector('button');button.disabled=true;button.textContent='Creating Herdr space…';const data=Object.fromEntries(new FormData(event.target));try{const result=await api('/api/projects',{method:'POST',body:JSON.stringify(data)});toast(result.warning||'Project space created');await loadProjects(result.project.id)}catch(error){toast(error.message,true);button.disabled=false;button.textContent='Create project space'}}
async function loadProjects(select){try{const payload=await api('/api/projects');state.projects=payload.projects;if(!state.projects.length){renderProjectStrip();renderAdd();return}const id=select||localStorage.getItem('wayfinder-project')||state.projects[0].id;await selectProject(state.projects.some(p=>p.id===id)?id:state.projects[0].id)}catch(error){$("main").innerHTML='<section class="card empty"><strong>Relay is unavailable</strong><span class="muted">'+esc(error.message)+'</span></section>';toast(error.message,true)}}
async function selectProject(id){state.project=state.projects.find(p=>p.id===id);if(!state.project)return;localStorage.setItem('wayfinder-project',id);state.frontiers={};renderProjectStrip();$("main").innerHTML='<div class="skeleton"></div><div class="skeleton"></div>';try{state.maps=await api('/api/projects/'+encodeURIComponent(id)+'/maps');if(!state.maps.length){renderDashboard();return}await loadFrontier()}catch(error){renderError(error)}}
async function frontierOf(number){if(!(number in state.frontiers))state.frontiers[number]=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/maps/'+number+'/frontier');return state.frontiers[number]}
async function loadFrontier(){state.sessions=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions');const chosen=Number(localStorage.getItem('wayfinder-map-'+state.project.id));if(state.maps.some(m=>m.number===chosen)){state.map=state.maps.find(m=>m.number===chosen)}else{const open=state.maps.filter(m=>m.state==='open');const counts=await Promise.all(open.map(async m=>[m,(await frontierOf(m.number)).length]));const best=counts.sort((a,b)=>b[1]-a[1]||a[0].number-b[0].number)[0];state.map=best?best[0]:state.maps[0];localStorage.setItem('wayfinder-map-'+state.project.id,String(state.map.number))}state.tickets=await frontierOf(state.map.number);renderDashboard()}
const STATUS_LABEL={working:'working',idle:'idle — ready for input',blocked:'blocked — needs your answer',gone:'session gone',unknown:'unknown'};
function liveCard(s){const gone=s.agentStatus==='gone';return '<article class="ticket"><div class="row between"><span class="badge">'+esc(s.type)+'</span><span class="ticket-meta">#'+s.ticket+' · '+esc(s.tabId)+'</span></div><div><h3>'+esc(s.title)+'</h3><p class="question"><span class="dot '+esc(s.agentStatus)+'"></span> '+esc(STATUS_LABEL[s.agentStatus]||s.agentStatus)+'</p></div><div class="row">'+(gone?'<button class="button grow" data-restart="'+s.ticket+'">Restart tab in space</button>':'<button class="button grow" data-open="'+s.paneId+'">Open terminal</button>')+'<button class="button secondary danger" data-stop="'+s.ticket+'">Close</button></div></article>'}
function renderTerminal(){const s=state.session;$("main").innerHTML='<section class="card"><div class="row between"><button class="button secondary" id="back">← Queue</button><span class="ticket-meta"><span class="dot '+esc(s.agentStatus)+'"></span> '+esc(STATUS_LABEL[s.agentStatus]||s.agentStatus)+'</span></div><h2 style="margin-top:12px">'+esc(s.title)+'</h2><p class="question">#'+s.ticket+' · '+esc(s.type)+' · '+esc(s.paneId)+'</p></section><section class="card live"><div class="bar"><span class="dot '+esc(s.agentStatus)+'" id="liveDot"></span><span class="muted" id="liveState">'+esc(STATUS_LABEL[s.agentStatus]||s.agentStatus)+'</span><button class="button secondary" id="closeTab" style="margin-left:auto">Close tab</button></div><pre class="term" id="term" aria-live="polite" aria-label="Ticket terminal"></pre><div class="keys" id="keys"></div><form class="composer" id="composer"><textarea id="input" placeholder="Type an answer, then Send" aria-label="Terminal input"></textarea><button class="button wide" type="submit">Send</button></form></section><p class="muted" style="padding:0 4px">Send appends a newline, so it submits. Send without one for a half-typed line, then press Enter.</p>';
 const term=$("term");let last=null;async function poll(){try{const data=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/panes/'+encodeURIComponent(s.paneId)+'?lines=140');if(data.text!==last){last=data.text;const stuck=term.scrollTop+term.clientHeight>=term.scrollHeight-40;term.textContent=data.text||'(no output yet)';if(stuck||data.text!==last)term.scrollTop=term.scrollHeight}if(data.agentStatus!==s.agentStatus){s.agentStatus=data.agentStatus;$("liveDot").className="dot "+data.agentStatus;$("liveState").textContent=STATUS_LABEL[data.agentStatus]||data.agentStatus}}catch(error){last=null;term.textContent=error.message}}poll();state.poll=setInterval(poll,1500);
 const keys=[["Esc","esc"],["Tab","tab"],["↑","up"],["↓","down"],["Ctrl+C","ctrl+c"],["Ctrl+D","ctrl+d"],["Ctrl+L","ctrl+l"]];$("keys").innerHTML=keys.map(k=>'<button class="key" data-key="'+k[1]+'">'+k[0]+'</button>').join('');$("keys").querySelectorAll('[data-key]').forEach(b=>b.onclick=async()=>{b.disabled=true;try{await api('/api/projects/'+encodeURIComponent(state.project.id)+'/panes/'+encodeURIComponent(s.paneId),{method:'POST',body:JSON.stringify({keys:[b.dataset.key]})})}catch(error){toast(error.message,true)}b.disabled=false});
 $("composer").onsubmit=async event=>{event.preventDefault();const input=$("input");const text=input.value;if(!text.trim())return;input.value="";input.disabled=true;try{await api('/api/projects/'+encodeURIComponent(state.project.id)+'/panes/'+encodeURIComponent(s.paneId),{method:'POST',body:JSON.stringify({text})})}catch(error){toast(error.message,true)}input.disabled=false;input.focus();poll()};
 $("back").onclick=()=>{clearInterval(state.poll);state.poll=0;renderDashboard()};
 $("closeTab").onclick=async()=>{if(!confirm('Close this ticket tab in Herdr? The ticket stays claimed on GitHub.'))return;try{await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions/'+s.ticket,{method:'DELETE'});clearInterval(state.poll);state.poll=0;toast('Tab closed');await loadFrontier()}catch(error){toast(error.message,true)}}}
function renderDashboard(){const p=state.project;const workspace=p.workspaceId?'<span class="badge">space '+esc(p.workspaceId)+'</span>':'<span class="badge">space pending</span>';const live=state.sessions.filter(s=>s.agentStatus!=='gone');const stopped=state.sessions.filter(s=>s.agentStatus==='gone');const liveCardHtml=live.length?'<section class="card"><p class="eyebrow">Live in Pi</p><div class="queue">'+live.map(liveCard).join('')+'</div></section>':'';const pastCard=stopped.length?'<details class="card"><summary>Closed sessions ('+stopped.length+')</summary><div class="queue">'+stopped.map(liveCard).join('')+'</div></details>':'';const mapOptions=state.maps.map(m=>'<option value="'+m.number+'" '+(state.map&&m.number===state.map.number?'selected':'')+'>'+esc(m.title)+' · '+m.sub_issues_summary.completed+'/'+m.sub_issues_summary.total+'</option>').join('');const next=state.tickets[0];const nextCard=next?'<section class="card ticket primary"><div class="row between"><p class="eyebrow">Next unblocked</p><span class="badge">'+esc(next.type)+'</span></div><div><h2>'+esc(next.title)+'</h2><p class="question">'+esc(next.question||'Open the ticket for the full question.')+'</p></div><div class="ticket-meta"><span>#'+next.number+'</span><span>unclaimed</span><span>ready now</span></div><button class="button wide" data-start="'+next.number+'">Start in Pi</button><a class="button secondary wide" href="'+esc(next.url)+'" target="_blank" rel="noreferrer">Open ticket</a></section>':'<section class="card empty"><strong>Frontier clear</strong><span class="muted">No open, unblocked, unclaimed child ticket on this map.</span></section>';const rest=state.tickets.slice(1).map(t=>'<article class="ticket"><div class="row between"><span class="badge">'+esc(t.type)+'</span><span class="muted">#'+t.number+'</span></div><div><h3>'+esc(t.title)+'</h3><p class="question">'+esc(t.question||'Open the ticket for the full question.')+'</p></div><button class="button" data-start="'+t.number+'">Start in Pi</button></article>').join('');$("main").innerHTML='<section class="card"><div class="row between"><div><p class="eyebrow">Project space</p><h2>'+esc(p.name)+'</h2></div>'+workspace+'</div><p class="muted">'+esc(p.repo)+'<br>'+esc(p.cwd)+'</p><div class="row"><button class="button secondary" id="refresh">Refresh</button><button class="button secondary danger" id="remove">Remove</button></div></section>'+(state.maps.length?'<section class="card"><label>Wayfinder map<select id="mapSelect">'+mapOptions+'</select></label><div class="metrics" style="margin-top:12px"><div class="metric"><strong>'+state.tickets.length+'</strong><span>ready now</span></div><div class="metric"><strong>'+state.map.sub_issues_summary.completed+'</strong><span>closed</span></div><div class="metric"><strong>'+Math.max(0,state.map.sub_issues_summary.total-state.map.sub_issues_summary.completed)+'</strong><span>left</span></div></div></section>':'<section class="card empty"><strong>No Wayfinder maps</strong><span class="muted">This repo has no issue labelled wayfinder:map.</span></section>')+nextCard+(rest?'<section class="card"><p class="eyebrow">Ready queue</p><div class="queue">'+rest+'</div></section>':'')+liveCardHtml+pastCard;$("refresh").onclick=()=>selectProject(p.id);$("remove").onclick=removeProject;const select=$("mapSelect");if(select)select.onchange=async()=>{state.map=state.maps.find(m=>m.number===Number(select.value));localStorage.setItem('wayfinder-map-'+p.id,String(state.map.number));state.tickets=await frontierOf(state.map.number);renderDashboard()};$("main").querySelectorAll('[data-start]').forEach(b=>b.onclick=()=>start(Number(b.dataset.start),b));$("main").querySelectorAll('[data-open]').forEach(b=>b.onclick=()=>{state.session=state.sessions.find(s=>s.paneId===b.dataset.open);renderTerminal();scrollTo({top:0,behavior:'smooth'})});$("main").querySelectorAll('[data-stop]').forEach(b=>b.onclick=async()=>{if(!confirm('Close this ticket tab in Herdr? The ticket stays claimed on GitHub.'))return;try{await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions/'+b.dataset.stop,{method:'DELETE'});toast('Tab closed');await loadFrontier()}catch(error){toast(error.message,true)}});$("main").querySelectorAll('[data-restart]').forEach(b=>b.onclick=async()=>{b.disabled=true;b.textContent='Starting in the project space…';try{const session=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions/'+b.dataset.restart+'/restart',{method:'POST'});state.sessions=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions');state.session=session;renderTerminal();scrollTo({top:0,behavior:'smooth'});toast('Tab '+session.tabId+' reopened in the project space')}catch(error){toast(error.message,true);b.disabled=false;b.textContent='Restart tab in space'}})}
async function start(ticket,button){button.disabled=true;button.textContent='Claiming and launching…';try{const session=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/start',{method:'POST',body:JSON.stringify({map:state.map.number,ticket})});state.sessions=await api('/api/projects/'+encodeURIComponent(state.project.id)+'/sessions');state.session=session;renderTerminal();scrollTo({top:0,behavior:'smooth'});toast('Pi started in '+session.tabId+' as '+session.agent)}catch(error){toast(error.message,true);button.disabled=false;button.textContent='Start in Pi'}}
async function removeProject(){if(!confirm('Remove this project from Relay? Its Herdr space stays open.'))return;await api('/api/projects/'+encodeURIComponent(state.project.id),{method:'DELETE'});toast('Project removed');await loadProjects()}
function renderError(error){$("main").innerHTML='<section class="card empty"><strong>Could not load this project</strong><span class="muted">'+esc(error.message)+'</span><p style="margin-top:16px"><button class="button secondary" id="retry">Retry</button></p></section>';$("retry").onclick=()=>selectProject(state.project.id);toast(error.message,true)}
loadProjects();
</script></body></html>`;
}

async function requestBody<T>(request: Request, limit = 1_000_000): Promise<T> {
  const text = await request.text();
  if (text.length > limit) throw new Error("Request body is too large");
  return JSON.parse(text) as T;
}

function json(value: unknown, status = 200): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
    },
  });
}

function errorResponse(error: unknown): Response {
  const message = error instanceof Error ? error.message : String(error);
  return json({ error: message }, /not found|not registered|not takeable/i.test(message) ? 404 : 400);
}

function assertLocalMutation(request: Request): void {
  if (request.method === "GET" || request.method === "HEAD") return;
  if (request.headers.get("sec-fetch-site") === "cross-site") throw new Error("Cross-site mutation rejected");
  // A bodyless DELETE carries no content type; only a body must be JSON.
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > 0 && !request.headers.get("content-type")?.startsWith("application/json")) {
    throw new Error("Request bodies must be application/json");
  }
}

async function handler(request: Request): Promise<Response> {
  const url = new URL(request.url);
  const path = url.pathname;
  try {
    assertLocalMutation(request);
    if (path === "/" && request.method === "GET") {
      return new Response(page(), {
        headers: {
          "content-type": "text/html; charset=utf-8",
          "cache-control": "no-store",
          "x-content-type-options": "nosniff",
          "referrer-policy": "no-referrer",
        },
      });
    }

    if (path === "/api/health" && request.method === "GET") return json({ ok: true });

    if (path === "/api/projects" && request.method === "GET") {
      const all = await projects();
      let workspaces: Workspace[] = [];
      try {
        workspaces = await listWorkspaces();
      } catch {
        // The dashboard still shows configured projects while Herdr is offline.
      }
      return json({
        projects: all.map((project) => ({
          ...project,
          workspaceOnline: Boolean(
            workspaces.find((workspace) => workspace.workspace_id === project.workspaceId),
          ),
        })),
      });
    }

    if (path === "/api/projects" && request.method === "POST") {
      const value = await requestBody<{ name?: string; repo?: string; cwd?: string }>(request);
      const name = value.name?.trim() ?? "";
      const repo = value.repo?.trim() ?? "";
      const cwd = value.cwd?.trim() ?? "";
      if (!name || !validRepo(repo) || !cwd.startsWith("/")) {
        return json({ error: "name, owner/repo, and an absolute checkout path are required" }, 400);
      }
      const stat = await Deno.stat(cwd);
      if (!stat.isDirectory) return json({ error: "checkout path is not a directory" }, 400);
      await command("gh", ["repo", "view", repo, "--json", "nameWithOwner"]);
      const all = await projects();
      if (all.some((project) => project.repo === repo)) {
        return json({ error: "That repo already has a project space" }, 409);
      }
      const project: Project = {
        id: `${slug(name)}-${crypto.randomUUID().slice(0, 8)}`,
        name,
        repo,
        cwd,
        createdAt: new Date().toISOString(),
      };
      all.push(project);
      await saveProjects(all);
      let warning: string | undefined;
      try {
        await ensureWorkspace(project);
      } catch (error) {
        warning = `Project saved; Herdr space will be retried on launch (${
          error instanceof Error ? error.message : error
        })`;
      }
      return json({ project, warning }, 201);
    }

    const projectMatch = path.match(/^\/api\/projects\/([^/]+)$/);
    if (projectMatch && request.method === "DELETE") {
      const id = decodeURIComponent(projectMatch[1]);
      const all = await projects();
      if (!all.some((project) => project.id === id)) return json({ error: "Project not found" }, 404);
      await saveProjects(all.filter((project) => project.id !== id));
      return json({ ok: true });
    }

    const mapsMatch = path.match(/^\/api\/projects\/([^/]+)\/maps$/);
    if (mapsMatch && request.method === "GET") {
      const project = (await projects()).find((entry) => entry.id === decodeURIComponent(mapsMatch[1]));
      if (!project) return json({ error: "Project not found" }, 404);
      return json(await mapsFor(project.repo));
    }

    const frontierMatch = path.match(/^\/api\/projects\/([^/]+)\/maps\/(\d+)\/frontier$/);
    if (frontierMatch && request.method === "GET") {
      const project = (await projects()).find((entry) => entry.id === decodeURIComponent(frontierMatch[1]));
      if (!project) return json({ error: "Project not found" }, 404);
      return json(await frontier(project.repo, Number(frontierMatch[2])));
    }

    const startMatch = path.match(/^\/api\/projects\/([^/]+)\/start$/);
    if (startMatch && request.method === "POST") {
      const project = (await projects()).find((entry) => entry.id === decodeURIComponent(startMatch[1]));
      if (!project) return json({ error: "Project not found" }, 404);
      const value = await requestBody<{ map?: number; ticket?: number }>(request);
      if (!value.map || !value.ticket) return json({ error: "map and ticket are required" }, 400);
      const map = (await mapsFor(project.repo)).find((entry) => entry.number === value.map);
      if (!map) return json({ error: "Map not found" }, 404);
      const ticket = (await frontier(project.repo, value.map)).find((entry) => entry.number === value.ticket);
      if (!ticket) return json({ error: "Ticket is no longer open, unblocked, and unclaimed" }, 409);
      return json(await startTicket(project, map, ticket), 201);
    }

    const sessionsMatch = path.match(/^\/api\/projects\/([^/]+)\/sessions$/);
    if (sessionsMatch && request.method === "GET") {
      const project = (await projects()).find((entry) => entry.id === decodeURIComponent(sessionsMatch[1]));
      if (!project) return json({ error: "Project not found" }, 404);
      return json(await sessionsOf(project));
    }

    const paneReadMatch = path.match(/^\/api\/projects\/([^/]+)\/panes\/([^/]+)$/);
    const paneId = paneReadMatch ? decodeURIComponent(paneReadMatch[2]) : "";
    if (paneReadMatch && request.method === "GET") {
      const session = await ownedPane(decodeURIComponent(paneReadMatch[1]), paneId);
      const lines = Math.min(400, Math.max(20, Number(url.searchParams.get("lines")) || 120));
      return json(await paneText(session, lines));
    }

    if (paneReadMatch && request.method === "POST") {
      const session = await ownedPane(decodeURIComponent(paneReadMatch[1]), paneId);
      const value = await requestBody<{ text?: string; keys?: string[] }>(request);
      if (value.text !== undefined) {
        const text = value.text.slice(0, 8_000);
        if (text.length === 0) return json({ error: "text is empty" }, 400);
        await herdr(["pane", "send-text", session.paneId, text]);
        if (text.endsWith("\n")) {
          await herdr(["pane", "send-keys", session.paneId, "enter"]);
        }
        return json({ ok: true });
      }
      const keys = (value.keys ?? []).slice(0, 8);
      if (keys.length === 0 || !keys.every((key) => typeof key === "string" && validKey(key))) {
        return json({ error: "keys must be logical key names such as enter, esc, tab, up, or ctrl+c" }, 400);
      }
      await herdr(["pane", "send-keys", session.paneId, ...keys]);
      return json({ ok: true });
    }

    const stopMatch = path.match(/^\/api\/projects\/([^/]+)\/sessions\/(\d+)$/);
    if (stopMatch && request.method === "DELETE") {
      const all = await projects();
      const entry = all.find((candidate) => candidate.id === decodeURIComponent(stopMatch[1]));
      if (!entry) return json({ error: "Project not found" }, 404);
      const target = entry.sessions?.find((candidate) => candidate.ticket === Number(stopMatch[2]));
      if (!target) return json({ error: "No session for that ticket" }, 404);
      if (!target.stopped) {
        try {
          await herdr(["tab", "close", target.tabId]);
        } catch {
          // The tab is already gone; the session is stopped either way.
        }
        target.stopped = true;
        await saveProjects(all);
      }
      return json({ ok: true });
    }

    const restartMatch = path.match(/^\/api\/projects\/([^/]+)\/sessions\/(\d+)\/restart$/);
    if (restartMatch && request.method === "POST") {
      const project = (await projects()).find((entry) => entry.id === decodeURIComponent(restartMatch[1]));
      if (!project) return json({ error: "Project not found" }, 404);
      const session = project.sessions?.find((candidate) => candidate.ticket === Number(restartMatch[2]));
      if (!session) return json({ error: "No session for that ticket" }, 404);
      if (!session.stopped) return json({ error: "That tab is still open" }, 409);
      return json(await restartSession(project, session), 201);
    }

    // Compatibility feed for the existing Omp wayfinder/grilling extensions.
    if (path === "/api/settings") {
      if (request.method === "GET") return json(await settings());
      const value = await requestBody<{ storageSubdir?: string }>(request);
      const storageSubdir = (value.storageSubdir ?? "default").replace(/[^A-Za-z0-9_.-]/g, "") || "default";
      await writeJson(SETTINGS_FILE, { storageSubdir });
      return json({ storageSubdir });
    }
    if (path === "/api/maps" && request.method === "GET") {
      return json((await readJson<{ maps: MapEntry[] }>(MAPS_FILE, { maps: [] })).maps);
    }
    if (path === "/api/maps" && request.method === "POST") {
      const value = await requestBody<{ repo?: string; number?: number; title?: string }>(request);
      if (!value.repo || !value.number) return json({ error: "repo and number are required" }, 400);
      const id = `${value.repo}#${value.number}`;
      const registry = await readJson<{ maps: MapEntry[] }>(MAPS_FILE, { maps: [] });
      let entry = registry.maps.find((map) => map.id === id);
      if (!entry) {
        entry = {
          id,
          repo: value.repo,
          number: value.number,
          title: value.title ?? "",
          addedAt: new Date().toISOString(),
        };
        registry.maps.push(entry);
        await writeJson(MAPS_FILE, registry);
      }
      return json(entry);
    }
    const historyMatch = path.match(/^\/api\/maps\/(.+)\/(history|rounds|answers)$/);
    if (historyMatch) {
      const id = decodeURIComponent(historyMatch[1]);
      const value = await history(id);
      if (request.method === "GET" && historyMatch[2] === "history") return json(value);
      if (request.method === "POST" && historyMatch[2] === "rounds") {
        const round = await requestBody<Omit<Round, "recordedAt">>(request);
        if (typeof round.number !== "number" || !round.title || !Array.isArray(round.questions)) {
          return json({ error: "number, title and questions are required" }, 400);
        }
        value.rounds = value.rounds.filter((entry) => entry.number !== round.number);
        value.rounds.push({ ...round, recordedAt: new Date().toISOString() });
        value.rounds.sort((left, right) => left.number - right.number);
        await saveHistory(id, value);
        return json({ ok: true });
      }
      if (request.method === "POST" && historyMatch[2] === "answers") {
        const answers = await requestBody<Omit<AnswerSet, "submittedAt"> & { submittedAt?: string }>(request);
        if (typeof answers.round !== "number" || !Array.isArray(answers.answers)) {
          return json({ error: "round and answers are required" }, 400);
        }
        value.answers.push({ ...answers, submittedAt: answers.submittedAt ?? new Date().toISOString() });
        await saveHistory(id, value);
        return json({ ok: true });
      }
    }

    return new Response("Not found", { status: 404 });
  } catch (error) {
    return errorResponse(error);
  }
}

function selfTest(): void {
  const issues: RawIssue[] = [
    {
      number: 1,
      title: "Ready",
      body: "## Question\nWhich route?",
      state: "open",
      html_url: "https://example.test/1",
      labels: [{ name: "wayfinder:grilling" }],
      assignees: [],
      issue_dependencies_summary: { blocked_by: 0 },
    },
    {
      number: 2,
      title: "Claimed",
      state: "open",
      html_url: "x",
      labels: [{ name: "wayfinder:task" }],
      assignees: [{ login: "dev" }],
    },
    {
      number: 3,
      title: "Blocked",
      state: "open",
      html_url: "x",
      labels: [{ name: "wayfinder:task" }],
      assignees: [],
      issue_dependencies_summary: { blocked_by: 1 },
    },
    {
      number: 4,
      title: "Closed",
      state: "closed",
      html_url: "x",
      labels: [{ name: "wayfinder:task" }],
      assignees: [],
    },
  ];
  const ready = frontierOf(issues);
  if (ready.length !== 1 || ready[0].number !== 1 || ready[0].question !== "Which route?") {
    throw new Error("frontier filtering self-test failed");
  }
  if (slug("Moon Down!") !== "moon-down" || validRepo("bad") || !validRepo("cernoh/moon-down")) {
    throw new Error("validation self-test failed");
  }
  for (const key of ["enter", "esc", "up", "tab", "ctrl+c", "ctrl+d", "shift+tab"]) {
    if (!validKey(key)) throw new Error(`validKey rejected ${key}`);
  }
  for (const key of ["", "; rm -rf /", "ctrl+alt+shift+q", "enter; reboot", "wat"]) {
    if (validKey(key)) throw new Error(`validKey accepted ${key}`);
  }
  console.log("wayfinder-dashboard self-test passed");
}

if (Deno.args.includes("--self-test")) {
  selfTest();
} else {
  Deno.serve({ port: PORT, hostname: BIND }, handler);
  console.log(`Wayfinder Relay listening on http://${BIND}:${PORT}`);
}
