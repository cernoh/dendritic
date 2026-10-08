// herdr-title-sync: forward the pi session title to the herdr pane, so herdr tabs/panes
// show the title instead of a generic label.
//
// Two modes:
//   - default          -> pi-sessions' autoTitle owns generation; this extension only
//                         forwards whatever title pi ends up with (setSessionName wrapper).
//   - herdrTitleSync.agent set -> a pi agent definition (~/.pi/agent/agents/<name>.md)
//                         owns generation. Exclusive: pi-sessions' autoTitle must be off
//                         (sessions.autoTitle.enable = false), otherwise two writers race.
//
// Herdr transport: pane.report_metadata({pane_id, title}) over the unix socket.
// @ts-nocheck
import fs from "node:fs";
import net from "node:net";
import path from "node:path";
import {
  buildSessionContext,
  convertToLlm,
  getAgentDir,
  serializeConversation,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";

const socketPath = process.env.HERDR_SOCKET_PATH;
const socketEndpoint =
  process.platform === "win32" && socketPath ? `\\\\.\\pipe\\${socketPath}` : socketPath;
const paneId = process.env.HERDR_PANE_ID;
const source = "herdr:pi";

function enabled() {
  return process.env.HERDR_ENV === "1" && !!socketPath && !!paneId;
}

// --- herdr transport ---------------------------------------------------------

function sendRequestAttempt(request: unknown, timeoutMs: number): Promise<boolean> {
  if (!enabled()) return Promise.resolve(true);
  return new Promise((resolve) => {
    let done = false;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const finish = (ok: boolean) => {
      if (done) return;
      done = true;
      if (timeout) clearTimeout(timeout);
      try { socket.destroy(); } catch {}
      resolve(ok);
    };
    const socket = net.createConnection(socketEndpoint!);
    socket.on("error", () => finish(false));
    socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
    socket.on("data", () => finish(true));
    socket.on("end", () => finish(false));
    timeout = setTimeout(() => finish(false), timeoutMs);
    timeout.unref?.();
  });
}

async function sendRequest(request: unknown): Promise<void> {
  if (await sendRequestAttempt(request, 500)) return;
  await sendRequestAttempt(request, 1500);
}

let seq = Date.now() * 1000;
let lastTitle: string | undefined;

function nextSeq() { return ++seq; }

function reportTitle(title: string | undefined) {
  if (!enabled()) return;
  const normalized = title?.trim() ? title.trim() : undefined;
  if (normalized === lastTitle) return;
  lastTitle = normalized;

  const params: Record<string, unknown> = {
    pane_id: paneId,
    source,
    seq: nextSeq(),
  };
  if (normalized) {
    params.title = normalized;
  } else {
    params.clear_title = true;
  }

  void sendRequest({
    id: `${source}:title:${Date.now()}:${Math.random().toString(36).slice(2)}`,
    method: "pane.report_metadata",
    params,
  });
}

// --- settings ----------------------------------------------------------------

// Mirrors pi-sessions' autoTitle defaults (extensions/shared/settings.ts) so an
// unconfigured herdrTitleSync.agent behaves like the stock title system. Duplicated
// rather than imported: pi-sessions ships no deep exports and its files are raw TS.
const DEFAULT_REFRESH_TURNS = 4;
const DEFAULT_TIMEOUT_SECS = 15;
const DEFAULT_TOKEN_BUDGET = 64;
const DEFAULT_PROMPT =
  `Name this coding session (under 80 chars). Be specific to what is being discussed. ` +
  `Your exact output will be displayed to the user, so make sure that it contains ONLY ` +
  `the title itself and nothing else.`;

type AutoTitleSettings = {
  refreshTurns: number;
  timeoutMs: number;
  tokenBudget: number;
  prompt: string;
  thinkingLevel: string | undefined;
};

function readGlobalSettings(): any {
  return SettingsManager.create(process.cwd()).getGlobalSettings() as any;
}

function autoTitleStillEnabled(): boolean {
  return readGlobalSettings()?.sessions?.autoTitle?.enable !== false;
}

function readSettings(): { agent: string | undefined; autoTitle: AutoTitleSettings } {
  const global = readGlobalSettings();
  const auto = global?.sessions?.autoTitle ?? {};
  return {
    agent: typeof global?.herdrTitleSync?.agent === "string"
      ? global.herdrTitleSync.agent.trim() || undefined
      : undefined,
    autoTitle: {
      refreshTurns: auto.refreshTurns ?? DEFAULT_REFRESH_TURNS,
      timeoutMs: (auto.timeoutSecs ?? DEFAULT_TIMEOUT_SECS) * 1000,
      tokenBudget: auto.tokenBudget ?? DEFAULT_TOKEN_BUDGET,
      prompt: (typeof auto.prompt === "string" && auto.prompt.trim()) || DEFAULT_PROMPT,
      thinkingLevel: typeof auto.thinkingLevel === "string" ? auto.thinkingLevel : undefined,
    },
  };
}

// --- title agent definition --------------------------------------------------

type TitleAgent = { model: string | undefined; thinking: string | undefined; prompt: string };

// Minimal `key: value` frontmatter read. Enough for model/thinking; no YAML dep.
function readTitleAgent(name: string): TitleAgent | undefined {
  const file = path.join(getAgentDir(), "agents", `${name}.md`);
  let raw: string;
  try {
    raw = fs.readFileSync(file, "utf8");
  } catch {
    return undefined;
  }

  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return undefined;
  const [, frontmatter, body] = match;

  let model: string | undefined;
  let thinking: string | undefined;
  for (const line of frontmatter.split("\n")) {
    const kv = line.match(/^(model|thinking)\s*:\s*(.*)$/);
    if (!kv) continue;
    const value = kv[2].trim().replace(/^["']|["']$/g, "");
    if (!value) continue;
    if (kv[1] === "model") model = value;
    else thinking = value;
  }

  return { model, thinking, prompt: body.trim() || DEFAULT_PROMPT };
}

// --- generation --------------------------------------------------------------

const CHAR_MAX = 80;

export function buildPrompt(
  conversationText: string,
  cwd: string | undefined,
  currentTitle: string | undefined,
  shouldPreserve: boolean,
  instructions: string,
): string {
  const sections = ["Generate the title from this session context.", "<session_context>"];
  if (cwd) sections.push(`<cwd>${cwd}</cwd>`);
  if (shouldPreserve) sections.push(`<current_title>${currentTitle ?? ""}</current_title>`);
  sections.push(`<conversation>\n${conversationText || "(none)"}\n</conversation>`);
  sections.push("</session_context>");
  sections.push(`<title_instructions>\n${instructions}\n</title_instructions>`);
  return sections.join("\n\n");
}

export function normalizeTitle(value: string): string | undefined {
  const collapsed = value
    .trim()
    .replace(/^["'`]+|["'`]+$/g, "")
    .replace(/\s+/g, " ")
    .replace(/[.!?]+$/g, "")
    .trim();
  if (!collapsed) return undefined;
  return collapsed.slice(0, CHAR_MAX).trim() || undefined;
}

function extractText(content: unknown[]): string {
  return content
    .filter((p: any) => p?.type === "text" && typeof p.text === "string")
    .map((p: any) => p.text)
    .join("\n");
}

function resolveModel(modelRegistry: any, ref: string | undefined, current: any) {
  if (!ref || ref === "inherit") return current;
  const [maybeProvider, maybeId] = ref.includes("/") ? ref.split("/", 2) : [undefined, ref];
  const found = maybeProvider
    ? modelRegistry.find(maybeProvider, maybeId)
    : modelRegistry.getAvailable().find((m: any) => m.id === maybeId);
  return found ?? current;
}

async function generateTitle(ctx: any, agent: TitleAgent, shouldPreserve: boolean) {
  const entries = ctx.sessionManager.getEntries();
  const messages = buildSessionContext(entries, ctx.sessionManager.getLeafId()).messages;
  const conversationText = serializeConversation(convertToLlm(messages));
  const currentTitle = ctx.sessionManager.getSessionName();
  const systemPrompt =
    shouldPreserve && currentTitle?.trim()
      ? `${agent.prompt}\n\nPreserve the current title unless the conversation has meaningfully shifted.`
      : agent.prompt;

  const model = resolveModel(
    ctx.modelRegistry,
    agent.model,
    ctx.model,
  );
  if (!model) throw new Error("No model available for title generation.");

  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), settings.autoTitle.timeoutMs);
  try {
    const response = await ctx.modelRegistry
      .streamSimple(
        model,
        {
          systemPrompt,
          messages: [
            { role: "user", content: [{ type: "text", text: buildPrompt(
              conversationText,
              ctx.cwd ?? process.cwd(),
              currentTitle,
              shouldPreserve,
              systemPrompt,
            ) }], timestamp: Date.now() },
          ],
        },
        {
          maxTokens: settings.autoTitle.tokenBudget,
          // Default the model's reasoning OFF: at tokenBudget 64 a reasoning model
          // spends the whole budget on thinking and returns no text at all.
          reasoning: agent.thinking && agent.thinking !== "off" ? agent.thinking : "off",
          signal: abort.signal,
          cacheRetention: "none",
        },
      )
      .result();
    if (response.stopReason === "error") {
      throw new Error(response.errorMessage || "Provider returned an error.");
    }
    if (response.stopReason === "aborted") throw new Error("Title request timed out.");
    if (response.stopReason === "length") {
      throw new Error(
        `Title request hit the ${settings.autoTitle.tokenBudget}-token budget before any text.`,
      );
    }
    const title = normalizeTitle(extractText(response.content));
    if (!title) throw new Error("Title agent returned an empty title.");
    return title;
  } finally {
    clearTimeout(timer);
  }
}

// --- auto-title state (shared shape with pi-sessions' pi-sessions.auto-title) --

const STATE_TYPE = "pi-sessions.auto-title";
let state: Record<string, any> = { version: 1, mode: "active", updatedAt: "" };

function restoreState(ctx: any) {
  const sessionFile = ctx.sessionManager.getSessionFile();
  const entries = ctx.sessionManager.getEntries() as any[];
  state = { version: 1, mode: "active", sessionFile, updatedAt: new Date().toISOString() };
  for (let i = entries.length - 1; i >= 0; i--) {
    const entry = entries[i];
    if (entry?.type === "custom" && entry.customType === STATE_TYPE && entry.data) {
      state = { ...state, ...entry.data };
      return;
    }
  }
}

function persistState(pi: any) {
  pi.appendEntry(STATE_TYPE, { ...state, updatedAt: new Date().toISOString() });
}

function userTurnCount(ctx: any): number {
  const messages = buildSessionContext(
    ctx.sessionManager.getEntries(),
    ctx.sessionManager.getLeafId(),
  ).messages;
  return messages.filter((m: any) => m.role === "user").length;
}

/** A /name rename (currentTitle !== lastAutoTitle) pauses automatic retitling. */
function pauseIfRenamed(ctx: any): "paused" | "renamed" | "active" {
  if (state.mode === "paused_manual") return "paused";
  const current = ctx.sessionManager.getSessionName();
  const last = state.lastAutoTitle;
  const unchanged = last === undefined ? !current : current === last;
  if (unchanged) return "active";
  state = { ...state, mode: "paused_manual" };
  return "renamed";
}

function resolveTrigger(ctx: any): "initial" | "periodic" | undefined {
  const turns = userTurnCount(ctx);
  if (!ctx.sessionManager.getSessionName() && !state.lastAutoTitle && turns === 1) {
    return "initial";
  }
  const since = turns - (state.lastAppliedUserTurnCount ?? 0);
  if (since < settings.autoTitle.refreshTurns) return undefined;
  return "periodic";
}

// --- extension ---------------------------------------------------------------

const settings = readSettings();

let inFlight: Promise<void> | undefined;
let warnedConflict = false;
let lastFailureKey: string | undefined;

function notifyFailure(message: string) {
  if (message === lastFailureKey) return;
  lastFailureKey = message;
  if (lastWarnCtx?.hasUI) {
    lastWarnCtx.ui.notify(`Title agent failed: ${message}`, "warning");
  }
}

let lastWarnCtx: any;

async function runTitle(ctx: any, pi: any, reason: "initial" | "periodic" | "manual") {
  const agent = settings.agent ? readTitleAgent(settings.agent) : undefined;
  if (!agent) {
    notifyFailure(`title agent "${settings.agent}" not found in ~/.pi/agent/agents/`);
    return;
  }
  try {
    const title = await generateTitle(ctx, agent, reason !== "initial");
    if (ctx.sessionManager.getSessionFile() !== state.sessionFile) return; // session switched
    pi.setSessionName(title); // wrapped below -> reportTitle -> herdr
    state = {
      ...state,
      mode: "active",
      lastAutoTitle: title,
      lastAppliedUserTurnCount: userTurnCount(ctx),
      lastTrigger: reason,
    };
    lastFailureKey = undefined;
  } catch (error: any) {
    notifyFailure(error?.message || "Unknown error.");
  }
}

function schedule(pi: any, ctx: any, reason: "initial" | "periodic" | "manual") {
  if (inFlight) return;
  lastWarnCtx = ctx;
  inFlight = runTitle(ctx, pi, reason)
    .then(() => persistState(pi))
    .catch(() => {})
    .finally(() => {
      inFlight = undefined;
    });
}

export default function (pi) {
  if (!enabled()) return;

  let rootTui = false;
  let wrapped = false;

  const tryWrap = () => {
    if (wrapped) return;
    const orig = pi.setSessionName?.bind(pi);
    if (!orig) return;
    wrapped = true;
    pi.setSessionName = (name: string) => {
      const res = orig(name);
      reportTitle(name);
      return res;
    };
  };
  tryWrap();

  const forwardCurrent = (ctx: any) => {
    const title = ctx?.sessionManager?.getSessionName?.();
    reportTitle(typeof title === "string" ? title : undefined);
  };

  pi.on("session_start", (_event, ctx) => {
    tryWrap();
    if (ctx?.mode !== "tui") return;
    rootTui = true;
    restoreState(ctx);
    forwardCurrent(ctx);

    if (!settings.agent) return;
    // pi-sessions keeps auto-titling and /title unless its feature toggle is off.
    if (!warnedConflict && autoTitleStillEnabled()) {
      warnedConflict = true;
      ctx.ui.notify(
        `herdrTitleSync.agent is set but sessions.autoTitle.enable is not false. ` +
          `Set it false so only one title writer runs.`,
        "warning",
      );
    }
  });

  pi.on("turn_end", (_event, ctx) => {
    if (!rootTui) return;
    forwardCurrent(ctx);
    if (!settings.agent) return;
    const paused = pauseIfRenamed(ctx);
    if (paused === "renamed") persistState(pi); // /name took over; stop auto-retitling
    if (paused !== "active") return;
    const reason = resolveTrigger(ctx);
    if (reason) schedule(pi, ctx, reason);
  });

  // /title is only registered by us when pi-sessions' autoTitle is disabled, so the
  // two never collide. Bulk scopes stay with pi-sessions' own backfill.
  if (settings.agent) {
    pi.registerCommand("title", {
      description: "Regenerate this session's title with the configured title agent",
      handler: async (_args: string, ctx: any) => {
        lastWarnCtx = ctx;
        await ctx.waitForIdle?.();
        if (inFlight) await inFlight;
        state = { ...state, mode: "active" };
        await runTitle(ctx, pi, "manual");
        persistState(pi);
      },
    });
  }
}
