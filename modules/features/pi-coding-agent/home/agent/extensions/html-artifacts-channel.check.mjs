// Run: node ~/.pi/agent/extensions/html-artifacts-channel.check.mjs
// Stubs the ExtensionAPI, fires before_agent_start, asserts the section lands
// and is stable across runs (no transcript churn).
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const file = new URL("./html-artifacts-channel.ts", import.meta.url);
const source = fs
	.readFileSync(file, "utf8")
	.replace(/^import[\s\S]*?from "@earendil-works\/pi-coding-agent";$/m, "");

const stub = `import { homedir } from "node:os";\nimport path from "node:path";\n`;

// node strips the remaining types from a .ts file; keep it out of the
// extensions dir (that path can be a read-only nix store symlink)
const temp = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "html-artifacts-")), "under-test.ts");
fs.writeFileSync(temp, stub + source);
const mod = await import(temp);

let handler;
mod.default({ on: (event, fn) => event === "before_agent_start" && (handler = fn) });
assert.ok(handler, "before_agent_start handler not registered");

const fire = () => {
	const event = { systemPromptOptions: { sections: {} } };
	handler(event);
	return event.systemPromptOptions.sections.artifact_channel;
};

const first = fire();
assert.ok(first && first.length > 400, "section missing or suspiciously short");
assert.equal(fire(), first, "section must be stable across agent starts");

// the guarantees this file exists to enforce
assert.match(first, /grilling/i);
assert.match(first, /frontier\.html/);
assert.match(first, /wayfinder/i);
assert.match(first, /stay Markdown \*\*in the tracker\*\*/i);
assert.match(first, /xdg-open/);
assert.match(first, /theme\.css/);
// paths must point at the installed skill, not a guess
assert.ok(first.includes(path.join(homedir(), ".agents", "skills", "html-artifacts")));

console.log("html-artifacts-channel: ok");

function homedir() {
	return process.env.HOME ?? "/root";
}