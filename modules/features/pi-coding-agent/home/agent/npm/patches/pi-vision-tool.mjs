#!/usr/bin/env node
// Re-apply the local pi-vision-tool patches after any npm install.
//
// node_modules is gitignored, so every `npm install` restores the pristine
// upstream extension and the describe_image tool goes back to failing against
// opencode Go. This runs as `postinstall` for that reason.
//
// Both patches fix the same thing: 1.3.7 was written against a plain
// OpenAI-compatible provider and does not know opencode Go's two extra rules.
//
//   node patches/pi-vision-tool.mjs           apply (idempotent)
//   node patches/pi-vision-tool.mjs --check   verify only; exit 1 if missing
//
// Verified against https://opencode.ai/inference/go/openai/v1/chat/completions
// with model mimo-v2.6-flash, 2026-11-03: without the session header the API
// answers 400 MissingSessionID; with it, `reasoning_effort: "off"` answers 400
// "must be one of 'none', 'low', 'medium' or 'high'" and `"none"` answers 200
// with 0 reasoning tokens. See ~/.pi/agent/AGENTS.md ("pi-vision-tool") for the
// full story.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(root, "node_modules", "pi-vision-tool", "extensions", "vision-tool.ts");
const checkOnly = process.argv.includes("--check");

// Patch 1 — send a conversation header to opencode.
//
// opencode's inference edge refuses a request without `x-opencode-session`
// (400 MissingSessionID, "cannot be routed efficiently"). Pi's own provider
// sends one; the tool's raw fetch does not, so every call on opencode Go died
// before the model was reached. One stable id per process = one per pi session,
// which is the granularity the router wants.
const PATCH_1 = {
	label: "vision-tool.ts: x-opencode-session header",
	anchor: `  const response = await fetch(\`\${baseUrl}/chat/completions\`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: \`Bearer \${apiKey}\`,
    },`,
	replacement: `  // [local patch] opencode Go rejects a request with no conversation header:
  // 400 MissingSessionID, "cannot be routed efficiently".
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: \`Bearer \${apiKey}\`,
  };
  if ((visionModel.provider ?? "").startsWith("opencode")) {
    headers["x-opencode-session"] = OPENCODE_SESSION_ID;
  }

  const response = await fetch(\`\${baseUrl}/chat/completions\`, {
    method: "POST",
    headers,`,
	verify: (text) => text.includes("x-opencode-session"),
};

// Patch 2 — the session id itself, plus the crypto import it needs.
const PATCH_2 = {
	label: "vision-tool.ts: OPENCODE_SESSION_ID constant",
	anchor: `import { dirname, join, resolve } from "node:path";`,
	replacement: `import { dirname, join, resolve } from "node:path";
import { randomUUID } from "node:crypto";`,
	verify: (text) => text.includes("OPENCODE_SESSION_ID = "),
};

const PATCH_2B = {
	label: "vision-tool.ts: OPENCODE_SESSION_ID definition",
	anchor: `const CONFIG_PATH = join(getAgentDir(), "vision-tool.json");`,
	replacement: `const CONFIG_PATH = join(getAgentDir(), "vision-tool.json");

// [local patch] Stable per process, i.e. per pi session: opencode routes and
// caches by this value.
const OPENCODE_SESSION_ID = \`session_\${randomUUID()}\`;`,
	verify: (text) => text.includes("OPENCODE_SESSION_ID = "),
};

// Patch 3 — pi's "off" level is not a value opencode accepts.
//
// The tool's default branch sends \`reasoning_effort: <pi level>\` verbatim, so
// the default (off) reached the API as "off", which opencode rejects with
// "Param Incorrect: reasoning_effort must be one of 'none', 'low', 'medium' or
// 'high'". "none" is the same intent and costs no reasoning tokens.
const PATCH_3 = {
	label: "vision-tool.ts: reasoning_effort off -> none",
	anchor: `): Record<string, unknown> | undefined {
  if (!visionModel.reasoning) return undefined;`,
	replacement: `): Record<string, unknown> | undefined {
  if (!visionModel.reasoning) return undefined;

  // [local patch] opencode accepts only none|low|medium|high; pi's "off" level
  // is rejected as "Param Incorrect".
  if ((visionModel.provider ?? "").startsWith("opencode") && level === "off") {
    return { reasoning_effort: "none" };
  }`,
	verify: (text) => text.includes('reasoning_effort: "none"'),
};

let failed = false;

for (const patch of [PATCH_1, PATCH_2, PATCH_2B, PATCH_3]) {
	let text;
	try {
		text = readFileSync(SRC, "utf8");
	} catch (error) {
		console.error(`pi-vision-tool patch: cannot read ${SRC}: ${error.message}`);
		failed = true;
		continue;
	}

	if (patch.verify(text)) {
		if (checkOnly) console.log(`ok   ${patch.label}`);
		else console.log(`keep ${patch.label} (already applied)`);
		continue;
	}

	if (checkOnly) {
		console.error(`FAIL ${patch.label} — patch is NOT applied`);
		failed = true;
		continue;
	}

	if (!text.includes(patch.anchor)) {
		console.error(`warn ${patch.label} — upstream anchor not found in vision-tool.ts.`);
		console.error("     Upstream pi-vision-tool changed shape; re-read the failure and");
		console.error("     update patches/pi-vision-tool.mjs.");
		failed = true;
		continue;
	}

	writeFileSync(SRC, text.replace(patch.anchor, patch.replacement));
	console.log(`fix  ${patch.label}`);
}

if (checkOnly && failed) {
	process.exit(1);
}
