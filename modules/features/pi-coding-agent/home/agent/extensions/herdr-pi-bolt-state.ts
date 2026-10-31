// Herdr state reporting for Pi-Bolt.
//
// Why this file exists, in one paragraph: Herdr 0.9.5 decides whether an
// agent's own reports own the pane ("full lifecycle hook authority") from a
// hard-coded allowlist of (source, agent) pairs — `("herdr:pi", "pi")` is the
// Pi entry (src/detect/mod.rs::full_lifecycle_hook_authority upstream). Pi-Bolt
// ships a compiled-in reporter that identifies as `("pi-bolt", "pi-bolt")`,
// which is not on that list, so Herdr keeps screen-scraping the pane with Pi's
// detection manifest. A running Pi-Bolt pane is then routinely misread as
// `blocked` — the "x" in the sidebar while the agent is working — and its
// session reference is not accepted either.
//
// So Pi-Bolt reports under Herdr's Pi identity here instead: same protocol as
// Herdr's own `herdr-agent-state.ts` v9 (`pane.report_agent` /
// `pane.report_agent_session` / `pane.release_agent` over
// `$HERDR_SOCKET_PATH`), same `("herdr:pi", "pi")` pair, plus a resume command
// that reopens the session with `pi-bolt` rather than `pi`.
//
// `-builtin:herdr` in settings.json turns Pi-Bolt's compiled-in reporter off.
// The two cannot coexist: Herdr keeps exactly ONE hook authority per pane and
// the last report wins, so a second reporter that is wrong about `blocked`
// would flap the state and the label.
//
// This file must NOT be named `herdr-agent-state.ts`: Pi-Bolt skips a file with
// that name (it recognises Herdr's Pi integration and defers to its own
// built-in). It is also loaded by plain `pi`, where it does nothing —
// `isPiBoltRuntime()` is false, and `pi` keeps using Herdr's own integration.
// @ts-nocheck

import net from "node:net";
import path from "node:path";

const SOURCE = "herdr:pi";
const AGENT = "pi";
const RESUME_COMMAND = "pi-bolt";
const WATCHDOG_MS = 10_000;

type AgentState = "working" | "blocked" | "idle";

function isPiBoltRuntime(env: Record<string, string | undefined>): boolean {
  // A compiled single-file Bun executable reports its own path here, which
  // contains `pi-bolt`; plain `pi` runs under node, whose execPath does not.
  if (/pi-bolt/i.test(String(process.execPath ?? ""))) {
    return true;
  }
  // Pi-Bolt sets this for its own process and children so that no second
  // Pi-side reporter in the same pane fights it.
  return env.PI_HERDR_NO_SELF_REPORT === "1";
}

class HerdrConnection {
  endpoint: string;
  paneId: string;
  seq: number;
  source: string;
  agent: string;

  constructor(endpoint: string, paneId: string, source: string, agent: string) {
    this.endpoint = endpoint;
    this.paneId = paneId;
    this.source = source;
    this.agent = agent;
    this.seq = Date.now() * 1000;
  }

  nextSeq(): number {
    this.seq += 1;
    return this.seq;
  }

  attempt(request: unknown, timeoutMs: number): Promise<boolean> {
    return new Promise((resolve) => {
      let done = false;
      let timeout: ReturnType<typeof setTimeout> | undefined;
      const finish = (delivered: boolean) => {
        if (done) return;
        done = true;
        if (timeout) clearTimeout(timeout);
        socket.destroy();
        resolve(delivered);
      };

      const socket = net.createConnection(this.endpoint);
      socket.on("error", () => finish(false));
      socket.on("connect", () => socket.write(`${JSON.stringify(request)}\n`));
      socket.on("data", () => finish(true));
      socket.on("end", () => finish(false));
      timeout = setTimeout(() => finish(false), timeoutMs);
      timeout.unref?.();
    });
  }

  // Herdr is best-effort by contract: a missing or slow server must never slow
  // the agent down, so a failed report is dropped rather than retried forever.
  async send(request: unknown): Promise<void> {
    if (await this.attempt(request, 500)) return;
    await this.attempt(request, 1500);
  }
}

type SessionRef = { agent_session_path?: string; agent_session_id?: string };

type QueuedReport = { state: AgentState; message?: string; seq: number; session: SessionRef; resumeArgv?: string[] };

export function createHerdrPiBoltExtension(
  env: Record<string, string | undefined> = process.env,
  options: { socketEndpoint?: string; resumeCommand?: string } = {},
) {
  return (pi: any) => {
    if (env.HERDR_ENV !== "1") return;
    if (!env.HERDR_SOCKET_PATH || !env.HERDR_PANE_ID) return;
    if (!isPiBoltRuntime(env)) return;

    const endpoint =
      options.socketEndpoint ??
      (process.platform === "win32" && env.HERDR_SOCKET_PATH
        ? `\\\\.\\pipe\\${env.HERDR_SOCKET_PATH}`
        : env.HERDR_SOCKET_PATH);
    const resumeCommand = options.resumeCommand ?? RESUME_COMMAND;
    const herdr = new HerdrConnection(endpoint, env.HERDR_PANE_ID, SOURCE, AGENT);

    let reporting = false;
    let sessionFile: string | undefined;
    let sessionId: string | undefined;
    let agentActive = false;
    let uiPrompt = false;
    let lastCtx: any;

    const blockedLabels: string[] = [];
    const runningSubagents = new Set<string>();

    let last: { state: AgentState; message?: string; sessionFile?: string } | undefined;
    let inFlight = false;
    let queued: QueuedReport | undefined;

    function resumeArgv(file: string | undefined): string[] | undefined {
      if (!file || !path.isAbsolute(file)) return undefined;
      const argv = [resumeCommand, "--session", file];
      const bad = argv.some((arg) => arg.includes("'") || /[\u0000-\u001f\u007f-\u009f]/.test(arg));
      if (bad) return undefined;
      const bytes = argv.reduce((total, arg) => total + Buffer.byteLength(arg), 0);
      if (argv.length > 64 || bytes > 8192) return undefined;
      return argv;
    }

    function updateSession(ctx: any): void {
      try {
        const file = ctx?.sessionManager?.getSessionFile?.();
        sessionFile = typeof file === "string" && path.isAbsolute(file) ? file : undefined;
      } catch {
        sessionFile = undefined;
      }
      try {
        const id = ctx?.sessionManager?.getSessionId?.();
        sessionId = typeof id === "string" && id.length > 0 ? id : undefined;
      } catch {
        sessionId = undefined;
      }
    }

    function sessionRef(): SessionRef {
      if (sessionFile) return { agent_session_path: sessionFile };
      if (sessionId) return { agent_session_id: sessionId };
      return {};
    }

    function desiredState(): { state: AgentState; message?: string } {
      const blocked = blockedLabels[blockedLabels.length - 1];
      if (blocked !== undefined) return { state: "blocked", message: blocked };
      if (uiPrompt && agentActive) return { state: "blocked", message: "waiting for you" };
      if (agentActive || runningSubagents.size > 0) return { state: "working" };
      return { state: "idle" };
    }

    async function drain(): Promise<void> {
      if (inFlight) return;
      inFlight = true;
      try {
        while (queued) {
          const report = queued;
          queued = undefined;
          await herdr.send({
            id: `${SOURCE}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
            method: "pane.report_agent",
            params: {
              pane_id: herdr.paneId,
              source: SOURCE,
              agent: AGENT,
              state: report.state,
              seq: report.seq,
              ...(report.message ? { message: report.message } : {}),
              ...report.session,
              ...(report.resumeArgv ? { resume_argv: report.resumeArgv } : {}),
            },
          });
        }
      } finally {
        inFlight = false;
        if (queued) void drain();
      }
    }

    function publish(force = false): void {
      if (!reporting) return;
      const next = { ...desiredState(), sessionFile };
      if (
        !force &&
        last &&
        last.state === next.state &&
        last.message === next.message &&
        last.sessionFile === next.sessionFile
      ) {
        return;
      }
      last = next;
      queued = {
        state: next.state,
        message: next.message,
        seq: herdr.nextSeq(),
        session: sessionRef(),
        resumeArgv: resumeArgv(sessionFile),
      };
      void drain();
    }

    function reportSession(reason?: string): void {
      const ref = sessionRef();
      if (!sessionFile && !sessionId) return;
      void herdr.send({
        id: `${SOURCE}:session:${Date.now()}:${Math.random().toString(36).slice(2)}`,
        method: "pane.report_agent_session",
        params: {
          pane_id: herdr.paneId,
          source: SOURCE,
          agent: AGENT,
          seq: herdr.nextSeq(),
          ...(reason ? { session_start_source: reason } : {}),
          ...ref,
          ...(resumeArgv(sessionFile) ? { resume_argv: resumeArgv(sessionFile) } : {}),
        },
      });
    }

    function clearTransientState(): void {
      // A new turn proves any prompt left open before it is gone. Without this,
      // one missed `ui_prompt_end` pins the pane at `blocked` for the rest of
      // the session — the failure this extension exists to avoid.
      uiPrompt = false;
      runningSubagents.clear();
    }

    pi.on("session_start", async (event: any, ctx: any) => {
      // TUI only: RPC/JSON/print modes are headless and are not what Herdr
      // shows in a pane.
      if (ctx?.mode !== "tui") return;
      reporting = true;
      lastCtx = ctx;
      updateSession(ctx);
      agentActive = ctx?.isIdle?.() === false;
      clearTransientState();
      reportSession(event?.reason);
      publish(true);
    });

    pi.on("agent_start", (_event: any, ctx: any) => {
      if (!reporting) return;
      lastCtx = ctx;
      updateSession(ctx);
      agentActive = true;
      clearTransientState();
      publish();
    });

    pi.on("agent_settled", (_event: any, ctx: any) => {
      if (!reporting) return;
      if (ctx?.isIdle?.() !== true) return;
      lastCtx = ctx;
      agentActive = false;
      clearTransientState();
      publish();
    });

    pi.on("ui_prompt_start", () => {
      if (!reporting) return;
      uiPrompt = true;
      publish();
    });

    pi.on("ui_prompt_end", () => {
      if (!reporting) return;
      uiPrompt = false;
      publish();
    });

    pi.events.on("herdr:blocked", (data: any) => {
      if (!reporting) return;
      if (data?.active) {
        blockedLabels.push(typeof data.label === "string" ? data.label : "");
      } else {
        blockedLabels.pop();
      }
      publish();
    });

    for (const [event, running] of [
      ["subagents:started", true],
      ["subagents:completed", false],
      ["subagents:failed", false],
    ] as const) {
      pi.events.on(event, (data: any) => {
        if (!reporting) return;
        const id = data?.id;
        if (typeof id !== "string") return;
        if (running) runningSubagents.add(id);
        else runningSubagents.delete(id);
        publish();
      });
    }

    // Safety net for a missed event: re-derive the turn state from the runtime
    // itself and republish when it disagrees with what Herdr was told.
    const watchdog = setInterval(() => {
      if (!reporting || !lastCtx) return;
      try {
        agentActive = lastCtx.isIdle?.() === false;
      } catch {
        return;
      }
      if (!agentActive) {
        uiPrompt = false;
        runningSubagents.clear();
      }
      publish();
    }, WATCHDOG_MS);
    watchdog.unref?.();

    pi.on("session_shutdown", async (event: any) => {
      if (!reporting) return;
      reporting = false;
      clearInterval(watchdog);
      if (event?.reason !== "quit") return;
      queued = undefined;
      await herdr.attempt(
        {
          id: `${SOURCE}:release:${Date.now()}`,
          method: "pane.release_agent",
          params: { pane_id: herdr.paneId, source: SOURCE, agent: AGENT, seq: herdr.nextSeq() },
        },
        500,
      );
    });
  };
}

export default createHerdrPiBoltExtension();
