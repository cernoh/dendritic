/**
 * grill-form — the `grill_form` and `grill_finish` tools.
 *
 * Purpose: run the `grill-me-html` loop. Each round becomes one HTML page with
 * a box per question and a submit button. A submit sends the answers back into
 * the live session as a user message, so the agent's next turn starts with
 * them. When the agent has no question left, `grill_finish` shows a
 * celebration page and the loop ends.
 *
 * Contract:
 * - The bridge server binds to 127.0.0.1 on an ephemeral port, and every route
 *   needs a random per-process token. Nothing but the session reads it.
 * - The pages, the round data, and the answers live in the HTML environment
 *   folder (see `lib/env.ts`), never in a repository.
 * - `pi.sendUserMessage` carries the answers. It starts a turn when the session
 *   is idle, and queues a steer while the session streams.
 * - The server holds the event loop only while a session runs: the handle is
 *   unref'd, and `session_shutdown` closes it.
 * - Question text is escaped. The page never runs source text as HTML.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { randomBytes, randomUUID } from "node:crypto";
import { copyFileSync, existsSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { createServer, type IncomingMessage, type Server, type ServerResponse } from "node:http";
import { join, normalize, resolve, sep } from "node:path";
import { escapeHtml, humanDate, openInBrowser, pageShell, slugify, stamp } from "./lib/html";
import { htmlEnv } from "./lib/env";

interface GrillQuestion {
  id: string;
  title: string;
  body?: string;
  recommendation?: string;
  choices?: string[];
}

interface Round {
  id: string;
  number: number;
  title: string;
  intro?: string;
  questions: GrillQuestion[];
  file: string;
}

interface Bridge {
  server: Server;
  base: string;
}

interface SubmittedAnswer {
  id: string;
  title: string;
  answer: string;
}

const FORM_CSS = `form#grill-form { display: grid; gap: 18px; }
.card.q {
  background: var(--card);
  border: 1.5px solid var(--line);
  border-radius: 10px;
  padding: 20px 22px;
  break-inside: avoid;
}
.q-label {
  margin: 0 0 6px;
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--accent);
}
.q-title { margin: 0 0 10px; font-family: var(--serif); font-size: 18px; font-weight: 500; }
.q-body p { margin: 0 0 10px; }
.q-body p:last-child { margin-bottom: 0; }
.q-answer { margin: 14px 0 0; padding: 10px 0 0 14px; border-left: 3px solid var(--success); }
.q-answer-label {
  margin: 0 0 4px;
  font-family: var(--mono);
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--success);
}
.q-answer p:last-child { margin-bottom: 0; }
.chips { display: flex; flex-wrap: wrap; gap: 6px; margin: 14px 0 0; }
.chips button {
  border: 1.5px solid var(--line);
  border-radius: 999px;
  background: var(--raised);
  color: var(--ink);
  font-family: var(--mono);
  font-size: 11.5px;
  padding: 4px 10px;
  cursor: pointer;
}
.chips button:hover { border-color: var(--accent); color: var(--accent); }
textarea {
  width: 100%;
  margin-top: 14px;
  padding: 11px 13px;
  background: var(--raised);
  color: var(--ink);
  border: 1.5px solid var(--line);
  border-radius: 8px;
  font-family: var(--sans);
  font-size: 14px;
  line-height: 1.5;
  resize: vertical;
}
textarea:focus { outline: 2px solid var(--accent); outline-offset: 1px; border-color: var(--accent); }
form.sent textarea { opacity: 0.7; }
.actions {
  position: sticky;
  bottom: 0;
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 0;
  background: linear-gradient(180deg, transparent, var(--background) 45%);
}
button.submit {
  border: 0;
  border-radius: 8px;
  background: var(--accent);
  color: var(--on-accent);
  font-family: var(--sans);
  font-size: 15px;
  font-weight: 600;
  padding: 12px 22px;
  cursor: pointer;
}
button.submit:disabled { opacity: 0.6; cursor: default; }
.hint { font-family: var(--mono); font-size: 11.5px; color: var(--faint); }
.status { margin-top: 10px; font-family: var(--mono); font-size: 12.5px; color: var(--muted); }
.status.error { color: var(--danger); }
.sent-box {
  margin-top: 18px;
  padding: 16px 18px;
  border: 1.5px dashed var(--success);
  border-radius: 10px;
  background: var(--card);
}
.sent-box h2 { margin: 0 0 6px; border: 0; padding: 0; font-size: 17px; }
@keyframes pulse-in {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: none; }
}
.sent-box { animation: pulse-in 260ms ease-out; }`;

const FORM_SCRIPT = `(function () {
  var form = document.getElementById("grill-form");
  if (!form) return;
  var status = document.getElementById("status");
  var submit = document.getElementById("submit");
  var sentBox = document.getElementById("sent-box");
  var endpoint = form.dataset.endpoint;
  var base = form.dataset.base;
  var roundNumber = Number(form.dataset.round);
  var boxes = form.querySelectorAll("textarea");
  var choices = form.querySelectorAll("[data-fill]");
  var polls = 0;

  var bindChoice = function (chip) {
    chip.addEventListener("click", function () {
      var box = document.getElementById(chip.dataset.target);
      if (!box) return;
      box.value = chip.dataset.fill;
      box.focus();
    });
  };
  for (var index = 0; index < choices.length; index += 1) bindChoice(choices[index]);

  var collect = function () {
    var answers = {};
    for (var index = 0; index < boxes.length; index += 1) answers[boxes[index].name] = boxes[index].value;
    return answers;
  };

  var follow = function () {
    polls += 1;
    if (polls > 240) return;
    fetch(base + "/state")
      .then(function (response) { return response.json(); })
      .then(function (state) {
        if (state.finished) { window.location.href = base + "/done"; return; }
        if (state.round > roundNumber) { window.location.href = base + "/round/" + state.round; return; }
        window.setTimeout(follow, 1500);
      })
      .catch(function () { window.setTimeout(follow, 3000); });
  };

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    submit.disabled = true;
    status.className = "status";
    status.textContent = "Sending…";
    fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ answers: collect() })
    })
      .then(function (response) {
        return response.json().catch(function () { return {}; }).then(function (body) {
          return { ok: response.ok, body: body };
        });
      })
      .then(function (result) {
        if (!result.ok) throw new Error(result.body && result.body.error ? result.body.error : "the server refused the submit");
        form.classList.add("sent");
        for (var index = 0; index < boxes.length; index += 1) boxes[index].readOnly = true;
        sentBox.hidden = false;
        status.textContent = "Sent. The session continues with your answers.";
        follow();
      })
      .catch(function (error) {
        submit.disabled = false;
        status.className = "status error";
        status.textContent = "Could not send: " + error.message;
      });
  });

  document.addEventListener("keydown", function (event) {
    if (event.key === "Enter" && (event.ctrlKey || event.metaKey)) submit.click();
  });
})();`;

const CELEBRATION_CSS = `* { --confetti-count: 90; }
.confetti { position: fixed; inset: 0; overflow: hidden; pointer-events: none; z-index: 5; }
.confetti span {
  position: absolute;
  top: -14px;
  width: 9px;
  height: 14px;
  border-radius: 2px;
  opacity: 0.9;
  animation-name: fall;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
}
@keyframes fall {
  0% { transform: translateY(-10vh) rotate(0deg); }
  100% { transform: translateY(112vh) rotate(540deg); }
}
@media (prefers-reduced-motion: reduce) {
  .confetti { display: none; }
}
main { position: relative; z-index: 10; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 14px; margin: 28px 0 34px; }
.stat {
  background: var(--card);
  border: 1.5px solid var(--line);
  border-radius: 10px;
  padding: 16px 18px;
}
.stat p { margin: 0; }
.stat .value { font-family: var(--serif); font-size: 30px; line-height: 1.1; }
.stat .label {
  font-family: var(--mono);
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--faint);
}
.decisions { background: var(--card); border: 1.5px solid var(--line); border-radius: 10px; padding: 20px 22px; }
.decisions h2 { margin: 0 0 12px; border: 0; padding: 0; font-size: 19px; }
.decisions ul { margin: 0; padding-left: 20px; }
.decisions li { margin: 6px 0; }
.report-link {
  display: inline-block;
  margin-top: 24px;
  padding: 12px 20px;
  border-radius: 8px;
  background: var(--accent);
  color: var(--on-accent);
  font-weight: 600;
  text-decoration: none;
}`;

const CELEBRATION_SCRIPT = `(function () {
  var layer = document.getElementById("confetti");
  if (!layer) return;
  var colors = ["var(--accent)", "var(--success)", "var(--link)", "var(--danger)"];
  for (var index = 0; index < 90; index += 1) {
    var piece = document.createElement("span");
    piece.style.left = (Math.random() * 100).toFixed(2) + "%";
    piece.style.background = colors[index % colors.length];
    piece.style.animationDelay = (Math.random() * 3).toFixed(2) + "s";
    piece.style.animationDuration = (3 + Math.random() * 2.5).toFixed(2) + "s";
    layer.appendChild(piece);
  }
})();`;

function paragraphsOf(text: string): string {
  return text
    .split(/\n\s*\n/)
    .map((part) => part.replace(/\n/g, " ").trim())
    .filter(Boolean)
    .map((part) => `<p>${escapeHtml(part)}</p>`)
    .join("");
}

/** Render the settled decisions of a celebration summary. */
function summaryList(markdown: string): string {
  const items: string[] = [];
  const rest: string[] = [];
  for (const rawLine of markdown.split("\n")) {
    const line = rawLine.trim();
    if (!line) continue;
    if (/^[-*]\s+/.test(line)) {
      items.push(`<li>${escapeHtml(line.replace(/^[-*]\s+/, ""))}</li>`);
      continue;
    }
    rest.push(`<p>${escapeHtml(line.replace(/^#+\s*/, ""))}</p>`);
  }
  const list = items.length > 0 ? `<ul>${items.join("")}</ul>` : "";
  return `${rest.join("")}${list}`;
}

function roundPage(round: Round, base: string): string {
  const cards = round.questions
    .map((question, index) => {
      const body = question.body ? `<div class="q-body">${paragraphsOf(question.body)}</div>` : "";
      const recommendation = question.recommendation
        ? `<div class="q-answer"><p class="q-answer-label">➡️ recommended</p>${paragraphsOf(question.recommendation)}</div>`
        : "";
      const choices =
        question.choices && question.choices.length > 0
          ? `<div class="chips">${question.choices
              .map(
                (choice) =>
                  `<button type="button" data-target="answer-${question.id}" data-fill="${escapeHtml(choice)}">${escapeHtml(choice)}</button>`,
              )
              .join("")}</div>`
          : "";
      return `<article class="card q">
<p class="q-label">❓ Q${index + 1}</p>
<p class="q-title">${escapeHtml(question.title)}</p>
${body}${recommendation}${choices}
<textarea id="answer-${question.id}" name="${question.id}" rows="3" placeholder="Your answer"></textarea>
</article>`;
    })
    .join("\n");

  return pageShell({
    eyebrow: `grill-me-html · round ${round.number}`,
    heading: round.title,
    sub: round.intro ?? "Fill each box, then submit. Partial answers are useful.",
    style: FORM_CSS,
    body: `<main>
<form id="grill-form" data-endpoint="${base}/round/${round.number}/answers" data-base="${base}" data-round="${round.number}">
${cards}
<article class="card q">
<p class="q-label">✚ catch-all</p>
<p class="q-title">Anything the round missed?</p>
<div class="q-body"><p>Leave it empty when there is nothing to add.</p></div>
<textarea id="answer-extra" name="extra" rows="2" placeholder="Optional"></textarea>
</article>
<div class="actions">
<button class="submit" id="submit" type="submit">Submit answers</button>
<span class="hint">Ctrl+Enter also submits</span>
</div>
</form>
<p class="status" id="status" role="status"></p>
<div class="sent-box" id="sent-box" hidden>
<h2>Answers sent</h2>
<p class="sub">The session continues in your terminal. This page follows the loop and opens the next round when it arrives.</p>
</div>
</main>`,
    script: FORM_SCRIPT,
    footer: [`round ${round.number}`, `${round.questions.length} questions`, humanDate()],
  });
}

function celebrationPage(input: {
  heading: string;
  summary?: string;
  rounds: number;
  answered: number;
  reportName?: string;
  base: string;
}): string {
  const decisions = input.summary ? `<section class="decisions"><h2>Settled decisions</h2>${summaryList(input.summary)}</section>` : "";
  const report = input.reportName
    ? `<a class="report-link" href="${input.base}/report">Open the full report</a>`
    : "";
  return pageShell({
    eyebrow: "grill-me-html · complete",
    heading: input.heading,
    sub: "Every branch of the design tree is settled.",
    style: CELEBRATION_CSS,
    body: `<div class="confetti" id="confetti" aria-hidden="true"></div>
<main>
<div class="stats">
<div class="stat"><p class="value">${input.rounds}</p><p class="label">rounds</p></div>
<div class="stat"><p class="value">${input.answered}</p><p class="label">answers</p></div>
<div class="stat"><p class="value">${input.reportName ? "1" : "0"}</p><p class="label">report</p></div>
</div>
${decisions}
${report}
</main>`,
    script: CELEBRATION_SCRIPT,
    footer: ["the loop is done", humanDate()],
  });
}

function answersMessage(round: Round, answers: SubmittedAnswer[], extra: string): string {
  const lines = answers.map((entry, index) => {
    const value = entry.answer.trim();
    return `${index + 1}. ${entry.title}\n   → ${value || "(left empty)"}`;
  });
  const tail = extra ? `\n\nAnything else the user added:\n→ ${extra}` : "";
  return `[grill-me-html] Form submitted for round ${round.number} (${round.title}).

${lines.join("\n")}${tail}

Continue the grill-me-html loop: recompute the frontier from these answers, send the next round with grill_form, and call grill_finish when no question remains.`;
}

function readBody(request: IncomingMessage, limit = 1_000_000): Promise<string> {
  const { promise, resolve: resolveBody, reject: rejectBody } = Promise.withResolvers<string>();
  const chunks: Buffer[] = [];
  let size = 0;
  request.on("data", (chunk: Buffer) => {
    size += chunk.length;
    if (size > limit) {
      rejectBody(new Error("Request body is too large."));
      request.destroy();
      return;
    }
    chunks.push(chunk);
  });
  request.on("end", () => resolveBody(Buffer.concat(chunks).toString("utf8")));
  request.on("error", rejectBody);
  return promise;
}

export default function grillFormExtension(pi: ExtensionAPI) {
  const z = pi.zod;
  const token = randomBytes(16).toString("hex");
  const rounds: Round[] = [];
  let finished = false;
  let answered = 0;
  let reportPath: string | undefined;
  let bridge: Bridge | undefined;
  let starting: Promise<Bridge> | undefined;

  const env = () => htmlEnv();

  function send(response: ServerResponse, status: number, body: string, type = "text/plain; charset=utf-8"): void {
    response.writeHead(status, { "content-type": type, "cache-control": "no-store" });
    response.end(body);
  }

  function sendJson(response: ServerResponse, status: number, value: unknown): void {
    send(response, status, JSON.stringify(value), "application/json; charset=utf-8");
  }

  function serveFile(response: ServerResponse, file: string, type: string): void {
    if (!existsSync(file) || !statSync(file).isFile()) {
      send(response, 404, "Not found");
      return;
    }
    send(response, 200, readFileSync(file, "utf8"), type);
  }

  async function handleSubmit(response: ServerResponse, round: Round, payload: unknown): Promise<void> {
    const answers = (payload as { answers?: unknown } | null)?.answers;
    if (!answers || typeof answers !== "object") {
      sendJson(response, 400, { error: "No answers in the request body." });
      return;
    }
    const received = answers as Record<string, unknown>;
    const submitted: SubmittedAnswer[] = round.questions.map((question) => ({
      id: question.id,
      title: question.title,
      answer: typeof received[question.id] === "string" ? (received[question.id] as string) : "",
    }));
    const extra = typeof received.extra === "string" ? (received.extra as string).trim() : "";
    writeFileSync(
      join(env().dataDir, `answers-${round.number}.json`),
      JSON.stringify(
        { round: round.number, title: round.title, submittedAt: new Date().toISOString(), answers: submitted, extra },
        null,
        2,
      ),
    );
    answered += submitted.filter((entry) => entry.answer.trim().length > 0).length;
    try {
      pi.sendUserMessage(answersMessage(round, submitted, extra));
    } catch (error) {
      sendJson(response, 500, { error: error instanceof Error ? error.message : String(error) });
      return;
    }
    sendJson(response, 200, { ok: true, answers: submitted.length });
  }

  function route(request: IncomingMessage, response: ServerResponse): void {
    const url = new URL(request.url ?? "/", "http://127.0.0.1");
    const segments = url.pathname.split("/").filter(Boolean);
    if (segments[0] !== "g" || segments[1] !== token) {
      send(response, 404, "Not found");
      return;
    }
    const rest = segments.slice(2);

    if (rest.length === 0) {
      const target = finished ? "done" : currentRound() ? `round/${currentRound()!.number}` : "done";
      response.writeHead(302, { location: `/g/${token}/${target}` });
      response.end();
      return;
    }

    if (rest[0] === "state") {
      sendJson(response, 200, {
        round: currentRound()?.number ?? 0,
        answered,
        finished,
      });
      return;
    }

    if (rest[0] === "done") {
      serveFile(response, join(env().publicDir, "done.html"), "text/html; charset=utf-8");
      return;
    }

    if (rest[0] === "report") {
      if (!reportPath) {
        send(response, 404, "No report for this session");
        return;
      }
      serveFile(response, reportPath, "text/html; charset=utf-8");
      return;
    }

    if (rest[0] === "env") {
      const relative = rest.slice(1).join("/");
      const target = resolve(join(env().publicDir, normalize(relative)));
      if (!target.startsWith(env().publicDir + sep)) {
        send(response, 403, "Forbidden");
        return;
      }
      const type = target.endsWith(".html")
        ? "text/html; charset=utf-8"
        : target.endsWith(".css")
          ? "text/css; charset=utf-8"
          : target.endsWith(".js")
            ? "text/javascript; charset=utf-8"
            : "application/octet-stream";
      serveFile(response, target, type);
      return;
    }

    if (rest[0] === "round" && rest[1]) {
      const round = rounds.find((entry) => String(entry.number) === rest[1]);
      if (!round) {
        send(response, 404, "Not found");
        return;
      }
      if (rest[2] === "answers" && request.method === "POST") {
        readBody(request)
          .then((body) => handleSubmit(response, round, JSON.parse(body) as unknown))
          .catch((error: unknown) => sendJson(response, 400, { error: error instanceof Error ? error.message : "Bad request" }));
        return;
      }
      serveFile(response, join(env().publicDir, round.file), "text/html; charset=utf-8");
      return;
    }

    send(response, 404, "Not found");
  }

  function currentRound(): Round | undefined {
    return rounds.find((round) => round.number === rounds.length) ?? rounds[rounds.length - 1];
  }

  function startBridge(): Promise<Bridge> {
    if (bridge) return Promise.resolve(bridge);
    if (starting) return starting;
    const { promise, resolve: resolveBridge, reject: rejectBridge } = Promise.withResolvers<Bridge>();
    const server = createServer((request, response) => {
      try {
        route(request, response);
      } catch (error) {
        sendJson(response, 500, { error: error instanceof Error ? error.message : String(error) });
      }
    });
    server.on("error", rejectBridge);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (!address || typeof address === "string") {
        rejectBridge(new Error("The bridge server has no port."));
        return;
      }
      server.unref();
      bridge = { server, base: `http://127.0.0.1:${address.port}/g/${token}` };
      resolveBridge(bridge);
    });
    starting = promise;
    return promise;
  }

  pi.setLabel("Grill Form");

  pi.on("session_shutdown", () => {
    bridge?.server.close();
    bridge = undefined;
    starting = undefined;
  });

  pi.registerTool({
    name: "grill_form",
    label: "Grill Form",
    description:
      "Serve one round of grilling questions as a web page with a text box per question and a submit button. " +
      "Call it with the whole frontier of one round. The tool opens the page in the browser and returns its URL. " +
      "End your turn after the call: the user's submit injects the answers into this session as a user message, " +
      "and your next turn starts with them. Do not type the questions in chat.",
    parameters: z.object({
      title: z.string().describe("Heading of the round page, for example the topic under discussion."),
      intro: z.string().optional().describe("One line above the questions."),
      round: z.number().optional().describe("Round number. Defaults to the next number."),
      questions: z
        .array(
          z.object({
            title: z.string().describe("The decision to settle, written as a question."),
            body: z.string().optional().describe("Context, options, and tradeoffs. Blank lines separate paragraphs."),
            recommendation: z.string().optional().describe("Your recommended answer."),
            choices: z.array(z.string()).optional().describe("Short options that fill the box on one click."),
          }),
        )
        .describe("The questions of this round, one per decision on the frontier."),
      open: z.boolean().optional().describe("Open the page in the browser. Default true."),
    }),
    loadMode: "essential",
    approval: "write",
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const requested = params.questions ?? [];
      if (requested.length === 0) {
        throw new Error("A round needs at least one question. Call grill_finish when no question remains.");
      }
      const number = params.round ?? rounds.length + 1;
      const questions: GrillQuestion[] = requested.map((question, index) => ({
        id: question.id?.trim() || `q${index + 1}`,
        title: question.title,
        body: question.body,
        recommendation: question.recommendation,
        choices: question.choices,
      }));
      const round: Round = {
        id: randomUUID(),
        number,
        title: params.title,
        intro: params.intro,
        questions,
        file: `round-${number}.html`,
      };
      const index = rounds.findIndex((entry) => entry.number === number);
      if (index >= 0) rounds[index] = round;
      else rounds.push(round);
      finished = false;

      const active = await startBridge();
      writeFileSync(
        join(env().dataDir, `round-${number}.json`),
        JSON.stringify({ number, title: round.title, intro: round.intro, questions }, null, 2),
      );
      writeFileSync(join(env().publicDir, round.file), roundPage(round, active.base));
      const page = `${active.base}/round/${number}`;
      if (params.open !== false) openInBrowser(page);

      return {
        content: [
          {
            type: "text",
            text:
              `Round ${number} form is open at ${page} (${questions.length} questions).\n` +
              `Environment: ${env().dir} (pages in public/, round data and answers in data/, dev shell: nix develop ${env().dir}).\n` +
              "Stop here. End the turn with one line that names the URL. The user's submit injects every answer as the next user message.",
          },
        ],
        details: { url: page, round: number, questions: questions.length, endpoint: `${active.base}/round/${number}/answers` },
      };
    },
  });

  pi.registerTool({
    name: "grill_finish",
    label: "Grill Finish",
    description:
      "End the grill-me-html loop with a celebration page. Call it once no question remains on the frontier. " +
      "Pass the settled decisions as Markdown list items, and the path of the finished HTML report to link it.",
    parameters: z.object({
      title: z.string().optional().describe("Heading of the celebration page."),
      summary: z.string().optional().describe("The settled decisions, as Markdown list items."),
      report: z.string().optional().describe("Path to the finished HTML report, linked from the page."),
      open: z.boolean().optional().describe("Open the page in the browser. Default true."),
    }),
    loadMode: "essential",
    approval: "write",
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const active = await startBridge();
      if (params.report && existsSync(params.report) && statSync(params.report).isFile()) {
        reportPath = join(env().publicDir, "report.html");
        copyFileSync(params.report, reportPath);
      }
      const heading = params.title?.trim() || "The design tree is settled";
      writeFileSync(
        join(env().publicDir, "done.html"),
        celebrationPage({
          heading,
          summary: params.summary,
          rounds: rounds.length,
          answered,
          reportName: reportPath ? "report.html" : undefined,
          base: active.base,
        }),
      );
      finished = true;
      const page = `${active.base}/done`;
      if (params.open !== false) openInBrowser(page);

      return {
        content: [
          {
            type: "text",
            text:
              `Celebration page is open at ${page}.\n` +
              `${rounds.length} rounds, ${answered} answers${reportPath ? ", report linked" : ""}. ` +
              `Environment: ${env().dir}.\n` +
              "Now write the record of the interview and render it with render_html, then report both paths.",
          },
        ],
        details: { url: page, rounds: rounds.length, answers: answered, report: reportPath },
      };
    },
  });
}
