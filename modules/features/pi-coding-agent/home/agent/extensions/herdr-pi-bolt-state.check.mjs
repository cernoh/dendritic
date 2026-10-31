// Run check for herdr-pi-bolt-state: node .pi/agent/extensions/herdr-pi-bolt-state.check.mjs
// Drives the extension against a fake Herdr API socket and asserts the bytes
// it would send: identity, session reference, resume command, and the state
// machine (including the stuck-prompt recovery that this file exists for).
import assert from "node:assert/strict";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { unlinkSync } from "node:fs";

import { createHerdrPiBoltExtension } from "./herdr-pi-bolt-state.ts";

const SESSION = "/home/tester/.pi/agent/sessions/--tmp--/2026-01-01T00-00-00-000Z_check.jsonl";

function fakeSocket() {
  const sock = path.join(os.tmpdir(), `herdr-pi-bolt-check-${process.pid}.sock`);
  const requests = [];
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.on("error", () => {});
    socket.on("data", (chunk) => {
      buffer += chunk.toString();
      let index;
      while ((index = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, index);
        buffer = buffer.slice(index + 1);
        if (!line.trim()) continue;
        requests.push(JSON.parse(line));
        socket.write(`${JSON.stringify({ result: {} })}\n`);
      }
    });
  });
  return {
    sock,
    requests,
    async open() {
      try {
        unlinkSync(sock);
      } catch {}
      await new Promise((resolve) => server.listen(sock, resolve));
    },
    async close() {
      await new Promise((resolve) => server.close(resolve));
    },
  };
}

function fakePi() {
  const handlers = new Map();
  const busHandlers = new Map();
  return {
    on(name, fn) {
      handlers.set(name, [...(handlers.get(name) ?? []), fn]);
    },
    events: {
      on(name, fn) {
        busHandlers.set(name, [...(busHandlers.get(name) ?? []), fn]);
      },
    },
    async fire(name, ...args) {
      for (const fn of handlers.get(name) ?? []) await fn(...args);
    },
    emit(name, data) {
      for (const fn of busHandlers.get(name) ?? []) fn(data);
    },
  };
}

function tuiContext({ idle }) {
  return {
    mode: "tui",
    isIdle: () => idle,
    sessionManager: {
      getSessionFile: () => SESSION,
      getSessionId: () => "check-session",
    },
  };
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 120));
const reports = (requests, method) => requests.filter((request) => request.method === method);
const states = (requests) =>
  reports(requests, "pane.report_agent").map((request) => request.params.state);

// --- plain `pi` is untouched: the gate must refuse to report ----------------
{
  const server = fakeSocket();
  await server.open();
  const pi = fakePi();
  createHerdrPiBoltExtension(
    { HERDR_ENV: "1", HERDR_SOCKET_PATH: "/tmp/ignored", HERDR_PANE_ID: "w1:p1" },
    { socketEndpoint: server.sock },
  )(pi);
  await pi.fire("session_start", { reason: "startup" }, tuiContext({ idle: true }));
  await settle();
  assert.equal(server.requests.length, 0, "must not report when not running under pi-bolt");
  await server.close();
}

// --- pi-bolt reports under Herdr's Pi identity -----------------------------
{
  const server = fakeSocket();
  await server.open();
  const pi = fakePi();
  createHerdrPiBoltExtension(
    {
      HERDR_ENV: "1",
      HERDR_SOCKET_PATH: server.sock,
      HERDR_PANE_ID: "w1:p1",
      PI_HERDR_NO_SELF_REPORT: "1",
    },
    { socketEndpoint: server.sock },
  )(pi);

  // Not a TUI (RPC/print): Herdr shows no PTY pane for it, so stay silent.
  await pi.fire("session_start", { reason: "startup" }, { ...tuiContext({ idle: true }), mode: "rpc" });
  await settle();
  assert.equal(server.requests.length, 0, "headless modes must not report");

  await pi.fire("session_start", { reason: "startup" }, tuiContext({ idle: true }));
  await settle();

  const [session] = reports(server.requests, "pane.report_agent_session");
  assert.ok(session, "session_start reports the session reference");
  assert.equal(session.params.source, "herdr:pi");
  assert.equal(session.params.agent, "pi");
  assert.equal(session.params.agent_session_path, SESSION);
  assert.deepEqual(session.params.resume_argv, ["pi-bolt", "--session", SESSION]);
  assert.equal(session.params.pane_id, "w1:p1");

  const first = reports(server.requests, "pane.report_agent").at(-1);
  assert.equal(first.params.state, "idle");
  assert.equal(first.params.source, "herdr:pi");
  assert.equal(first.params.agent, "pi");

  // A turn: working, and a fresh turn clears a prompt left open by the last one.
  await pi.fire("agent_start", {}, tuiContext({ idle: false }));
  await pi.fire("ui_prompt_start", {});
  await settle();
  assert.equal(states(server.requests).at(-1), "blocked", "an open prompt blocks the pane");

  await pi.fire("agent_start", {}, tuiContext({ idle: false }));
  await settle();
  assert.equal(states(server.requests).at(-1), "working", "a new turn clears a stale prompt");

  await pi.fire("agent_settled", {}, tuiContext({ idle: true }));
  await settle();
  assert.equal(states(server.requests).at(-1), "idle");

  // Blocked labels from other extensions round-trip.
  pi.emit("herdr:blocked", { active: true, label: "pick a model" });
  await settle();
  const blocked = reports(server.requests, "pane.report_agent").at(-1);
  assert.equal(blocked.params.state, "blocked");
  assert.equal(blocked.params.message, "pick a model");
  pi.emit("herdr:blocked", { active: false });
  await settle();
  assert.equal(states(server.requests).at(-1), "idle");

  // Subagents keep the pane working after the turn settles.
  pi.emit("subagents:started", { id: "sa1" });
  await settle();
  assert.equal(states(server.requests).at(-1), "working");
  pi.emit("subagents:completed", { id: "sa1" });
  await settle();
  assert.equal(states(server.requests).at(-1), "idle");

  // Sequence numbers must strictly increase, or Herdr drops the report.
  const seqs = reports(server.requests, "pane.report_agent").map((request) => request.params.seq);
  for (let i = 1; i < seqs.length; i += 1) {
    assert.ok(seqs[i] > seqs[i - 1], "seq must increase with every report");
  }

  // Quitting releases the pane identity.
  await pi.fire("session_shutdown", { reason: "quit" }, tuiContext({ idle: true }));
  await settle();
  const [release] = reports(server.requests, "pane.release_agent");
  assert.ok(release, "quit releases the pane");
  assert.equal(release.params.source, "herdr:pi");
  assert.equal(release.params.agent, "pi");

  await server.close();
}

console.log("herdr-pi-bolt-state: ok");
