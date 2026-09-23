/**
 * Wayfinder dashboard: one M3 page over every wayfinder map omp registers.
 *
 * Omp registers a map it is asked about (POST /api/maps); the dashboard
 * stores grill rounds + answers per map (POST .../rounds, .../answers) and
 * shows them with a since-last-boot filter. Live rounds embed the
 * grill_form loopback page in an iframe, so submits still inject into the
 * session. WebMCP tools in /webmcp.js mirror the read API for in-browser
 * agents. History lives under DATA_ROOT (mounted at /data).
 */

const PORT = Number(Deno.env.get("PORT") ?? "8787");
const DATA_ROOT = Deno.env.get("DATA_ROOT") ?? "/data";

// Sepia M3 tokens arrive from Nix (self.scheme.hex); page falls back to the
// same values when the env is absent, so local `deno task start` matches.
const T = (k: string, fb: string) => Deno.env.get(`M3_${k}`) ?? fb;
const theme = {
  primary: T("PRIMARY", "#c99a5b"),
  onPrimary: T("ON_PRIMARY", "#241c12"),
  primaryContainer: T("PRIMARY_CONTAINER", "#6b4f2a"),
  surface: T("SURFACE", "#241d17"),
  surfaceVariant: T("SURFACE_VARIANT", "#302619"),
  base: T("BASE", "#1e1813"),
  text: T("TEXT", "#ece0cd"),
  textDim: T("TEXT_DIM", "#9c8c74"),
  outline: T("OUTLINE", "#5f4d3a"),
  error: T("ERROR", "#c56a5a"),
  success: T("SUCCESS", "#8f9a6a"),
};

interface MapEntry {
  id: string;
  repo: string;
  number: number;
  title: string;
  addedAt: string;
}
interface RoundQ {
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
  questions: RoundQ[];
  formUrl?: string;
  recordedAt: string;
}
interface AnswerSet {
  round: number;
  answers: { id: string; title: string; answer: string }[];
  extra?: string;
  submittedAt: string;
}

const REG_FILE = `${DATA_ROOT}/registry.json`;
const SETTINGS_FILE = `${DATA_ROOT}/settings.json`;
const histPath = (id: string, sub: string) =>
  `${DATA_ROOT}/${sub}/history-${id.replace(/[^A-Za-z0-9_.-]/g, "_")}.json`;

async function readJson<T>(path: string, fb: T): Promise<T> {
  try {
    return JSON.parse(await Deno.readTextFile(path)) as T;
  } catch {
    return fb;
  }
}
async function writeJson(path: string, value: unknown): Promise<void> {
  await Deno.mkdir(path.slice(0, path.lastIndexOf("/")), { recursive: true });
  await Deno.writeTextFile(path, JSON.stringify(value, null, 2));
}
const readSettings = async () =>
  await readJson<{ storageSubdir: string }>(SETTINGS_FILE, { storageSubdir: "default" });
const readHistory = async (id: string) => {
  const { storageSubdir } = await readSettings();
  return await readJson<{ rounds: Round[]; answers: AnswerSet[] }>(
    histPath(id, storageSubdir),
    { rounds: [], answers: [] },
  );
};
const saveHistory = async (id: string, h: { rounds: Round[]; answers: AnswerSet[] }) => {
  const { storageSubdir } = await readSettings();
  await writeJson(histPath(id, storageSubdir), h);
};
// Boot time: btime survives container restarts of the server process, so the
// since-last-boot filter follows the machine, not the container.
async function bootTime(): Promise<string> {
  try {
    for (const line of (await Deno.readTextFile("/proc/stat")).split("\n")) {
      if (line.startsWith("btime")) return new Date(Number(line.split(/\s+/)[1]) * 1000).toISOString();
    }
  } catch { /* non-Linux */ }
  return new Date(Date.now() - 24 * 3600 * 1000).toISOString();
}


function page(): string {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Wayfinder dashboard</title>
<style>
:root{--primary:${theme.primary};--on-primary:${theme.onPrimary};--primary-container:${theme.primaryContainer};
--surface:${theme.surface};--surface-variant:${theme.surfaceVariant};--base:${theme.base};
--text:${theme.text};--dim:${theme.textDim};--outline:${theme.outline};--error:${theme.error};--success:${theme.success};}
*{box-sizing:border-box}body{margin:0;background:var(--base);color:var(--text);
font:15px/1.5 system-ui,sans-serif}
m3e-app-bar,header.top{display:flex;align-items:center;gap:12px;padding:14px 20px;
background:var(--surface);border-bottom:1px solid var(--outline);position:sticky;top:0;z-index:5}
header.top h1{font-size:19px;margin:0}header.top .sub{color:var(--dim);font-size:13px}
main{display:grid;gap:16px;padding:20px;max-width:1100px;margin:0 auto}
.card{background:var(--surface);border:1px solid var(--outline);border-radius:16px;padding:16px 18px}
.card h2{font-size:15px;margin:0 0 10px}select,input[type=text]{background:var(--surface-variant);
color:var(--text);border:1px solid var(--outline);border-radius:10px;padding:8px 10px;font:inherit;max-width:100%}
button{background:var(--primary);color:var(--on-primary);border:0;border-radius:20px;
padding:8px 18px;font:inherit;font-weight:600;cursor:pointer}
button.ghost{background:transparent;color:var(--primary);border:1px solid var(--outline)}
.chips{display:flex;gap:8px;flex-wrap:wrap}.chip{border:1px solid var(--outline);border-radius:8px;
padding:6px 12px;font-size:13px;background:var(--surface-variant)}
.chip[aria-pressed=true]{background:var(--primary-container)}
.round{border-top:1px solid var(--outline);padding:12px 0}.round h3{margin:0 0 4px;font-size:14px}
.q{margin:8px 0}.q .a{background:var(--surface-variant);border-radius:8px;padding:8px 10px;white-space:pre-wrap}
iframe.live{width:100%;min-height:560px;border:1px solid var(--outline);border-radius:12px;background:#fff}
.meta{color:var(--dim);font-size:12px}.row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}
</style>
<script src="/m3e.js" defer></script>
</head><body>
<m3e-theme color="${theme.primary}" variant="expressive" scheme="dark" motion="expressive">
<main>
<section class="card"><h2>Maps</h2><div class="row">
<select id="maps" aria-label="Wayfinder map"></select>
<input type="text" id="newRepo" placeholder="owner/repo" size="18">
<input type="text" id="newNum" placeholder="map #" size="6" inputmode="numeric">
<input type="text" id="newTitle" placeholder="title" size="24">
<button id="add">Register</button></div>
<p class="meta">Omp registers the map it is asked about here; GitHub stays the source of truth.</p></section>
<section class="card"><h2>Live round</h2><div id="live"><p class="meta">No live round for this map yet.</p></div></section>
<section class="card"><h2>History</h2><div class="chips" role="group" aria-label="History filter">
<button class="chip" id="fBoot" aria-pressed="true">Since last boot</button>
<button class="chip" id="fAll" aria-pressed="false">All</button></div>
<div id="hist"></div></section>
<section class="card"><h2>Settings</h2><div class="row">
<label>Storage subdir under /data <input type="text" id="subdir" size="16"></label>
<button id="saveSub" class="ghost">Save</button>
<span class="meta" id="subMsg"></span></div></section>
</main></m3e-theme>
<script>
let sinceBoot=true,maps=[],current=null,boot="";
async function j(u,o){const r=await fetch(u,o);if(!r.ok)throw new Error(await r.text());return r.json();}
async function loadBoot(){boot=(await j("/api/boot")).bootTime;
$("boot").textContent="boot "+new Date(boot).toLocaleString();}
async function loadMaps(){maps=await j("/api/maps");
const s=$("maps");s.innerHTML=maps.map(m=>'<option value="'+m.id+'">'+m.repo+" #"+m.number+" — "+m.title.replace(/</g,"&lt;")+"</option>").join("")||'<option value="">(no maps yet)</option>';
if(maps.length){current=maps[0].id;s.value=current;loadHist();}}
async function loadHist(){if(!current)return;const h=await j("/api/maps/"+encodeURIComponent(current)+"/history");
const ans=h.answers.filter(a=>!sinceBoot||a.submittedAt>=boot);
$("hist").innerHTML=h.rounds.map(r=>{
const ra=ans.filter(a=>a.round===r.number);
return '<div class="round"><h3>Round '+r.number+": "+r.title.replace(/</g,"&lt;")+'</h3>'
+'<p class="meta">'+r.recordedAt+(r.formUrl?' · <a href="'+r.formUrl+'">open form</a>':"")+'</p>'
+r.questions.map(q=>{const a=ra.flatMap(x=>x.answers).find(x=>x.id===q.id);
return '<div class="q"><div>'+q.title.replace(/</g,"&lt;")+'</div>'
+(a&&a.answer?'<div class="a">'+a.answer.replace(/</g,"&lt;")+"</div>":'<div class="meta">unanswered</div>')+"</div>";}).join("")+"</div>";}).join("")||'<p class="meta">No rounds yet.</p>';
const last=h.rounds[h.rounds.length-1];
$("live").innerHTML=last&&last.formUrl?'<iframe class="live" src="'+last.formUrl+'" title="Live grill round"></iframe>':'<p class="meta">No live round for this map yet.</p>';}
$("maps").onchange=e=>{current=e.target.value;loadHist();};
$("add").onclick=async()=>{const m=await j("/api/maps",{method:"POST",headers:{"content-type":"application/json"},
body:JSON.stringify({repo:$("newRepo").value.trim(),number:Number($("newNum").value),title:$("newTitle").value.trim()})});
current=m.id;await loadMaps();};
$("fBoot").onclick=()=>{sinceBoot=true;$("fBoot").setAttribute("aria-pressed","true");$("fAll").setAttribute("aria-pressed","false");loadHist();};
$("fAll").onclick=()=>{sinceBoot=false;$("fAll").setAttribute("aria-pressed","true");$("fBoot").setAttribute("aria-pressed","false");loadHist();};
$("saveSub").onclick=async()=>{await j("/api/settings",{method:"POST",headers:{"content-type":"application/json"},
body:JSON.stringify({storageSubdir:$("subdir").value.trim()||"default"})});
$("subMsg").textContent="saved";loadHist();};
(async()=>{await loadBoot();const s=await j("/api/settings");$("subdir").value=s.storageSubdir;await loadMaps();})();
</script>
<script>if(document.modelContext||navigator.modelContext){const s=document.createElement("script");s.src="/webmcp.js";document.head.append(s);}</script>
</body></html>`;
}

// WebMCP: same shapes as the REST read API, for in-browser agents.
function webmcpJs(): string {
  return `const mc=document.modelContext||navigator.modelContext;if(!mc)return;
const j=async u=>(await fetch(u)).json();
mc.registerTool({name:"list_maps",description:"List wayfinder maps registered on this dashboard.",
inputSchema:{type:"object",properties:{}},annotations:{readOnlyHint:true},
execute:async()=>({content:[{type:"text",text:JSON.stringify(await j("/api/maps"))}]})});
mc.registerTool({name:"list_rounds",description:"List grill rounds and answers for one map.",
inputSchema:{type:"object",properties:{map:{type:"string"}},required:["map"]},annotations:{readOnlyHint:true},
execute:async({map})=>({content:[{type:"text",text:JSON.stringify(await j("/api/maps/"+encodeURIComponent(map)+"/history"))}]})});`;
}

async function body(req: Request, limit = 1_000_000): Promise<unknown> {
  const text = await req.text();
  if (text.length > limit) throw new Error("Body too large");
  return JSON.parse(text);
}

Deno.serve({ port: PORT, hostname: "0.0.0.0" }, async (req) => {
  const url = new URL(req.url);
  const json = (v: unknown, s = 200) =>
    new Response(JSON.stringify(v), { status: s, headers: { "content-type": "application/json" } });
  try {
    if (url.pathname === "/" && req.method === "GET") {
      return new Response(page(), { headers: { "content-type": "text/html; charset=utf-8" } });
    }
    if (url.pathname === "/webmcp.js") {
      return new Response(webmcpJs(), { headers: { "content-type": "text/javascript" } });
    }
    if (url.pathname === "/m3e.js") {
      try {
        return new Response(await Deno.readFile("./m3e.js"), { headers: { "content-type": "text/javascript" } });
      } catch {
        return new Response("/* m3e bundle absent: rebuild the image */", { headers: { "content-type": "text/javascript" } });
      }
    }
    if (url.pathname === "/api/boot") return json({ bootTime: await bootTime() });
    if (url.pathname === "/api/settings") {
      if (req.method === "GET") return json(await readSettings());
      const b = await body(req) as { storageSubdir?: string };
      const sub = (b.storageSubdir ?? "default").replace(/[^A-Za-z0-9_.-]/g, "") || "default";
      await writeJson(SETTINGS_FILE, { storageSubdir: sub });
      return json({ storageSubdir: sub });
    }
    if (url.pathname === "/api/maps" && req.method === "GET") {
      return json((await readJson<{ maps: MapEntry[] }>(REG_FILE, { maps: [] })).maps);
    }
    if (url.pathname === "/api/maps" && req.method === "POST") {
      const b = await body(req) as { repo?: string; number?: number; title?: string };
      if (!b.repo || !b.number) return json({ error: "repo and number are required" }, 400);
      const id = `${b.repo}#${b.number}`;
      const reg = await readJson<{ maps: MapEntry[] }>(REG_FILE, { maps: [] });
      let e = reg.maps.find((m) => m.id === id);
      if (!e) {
        e = { id, repo: b.repo, number: b.number, title: b.title ?? "", addedAt: new Date().toISOString() };
        reg.maps.push(e);
        await writeJson(REG_FILE, reg);
      }
      return json(e);
    }
    const m = url.pathname.match(/^\/api\/maps\/(.+)\/(history|rounds|answers)$/);
    if (m) {
      const id = decodeURIComponent(m[1]);
      const h = await readHistory(id);
      if (req.method === "GET" && m[2] === "history") return json(h);
      if (req.method === "POST" && m[2] === "rounds") {
        const b = await body(req) as Omit<Round, "recordedAt">;
        if (typeof b.number !== "number" || !b.title || !Array.isArray(b.questions)) {
          return json({ error: "number, title and questions are required" }, 400);
        }
        h.rounds = h.rounds.filter((r) => r.number !== b.number);
        h.rounds.push({ ...b, recordedAt: new Date().toISOString() });
        h.rounds.sort((a, b2) => a.number - b2.number);
        await saveHistory(id, h);
        return json({ ok: true });
      }
      if (req.method === "POST" && m[2] === "answers") {
        const b = await body(req) as Omit<AnswerSet, "submittedAt"> & { submittedAt?: string };
        if (typeof b.round !== "number" || !Array.isArray(b.answers)) {
          return json({ error: "round and answers are required" }, 400);
        }
        h.answers.push({ ...b, submittedAt: b.submittedAt ?? new Date().toISOString() });
        await saveHistory(id, h);
        return json({ ok: true });
      }
    }
    return new Response("Not found", { status: 404 });
  } catch (e) {
    return json({ error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
