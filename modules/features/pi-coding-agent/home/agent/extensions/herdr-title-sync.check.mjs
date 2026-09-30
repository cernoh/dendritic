// Run check for herdr-title-sync: node .pi/agent/extensions/herdr-title-sync.check.mjs
// Stubs the pi package import, then asserts the pure title helpers.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const source = fs.readFileSync(
  new URL("./herdr-title-sync.ts", import.meta.url),
  "utf8",
);
const agentDir = fs.mkdtempSync(path.join(os.tmpdir(), "herdr-title-"));
fs.mkdirSync(path.join(agentDir, "agents"), { recursive: true });
fs.writeFileSync(
  path.join(agentDir, "agents", "title-generator.md"),
  `---\nname: title-generator\nmodel: anthropic/claude-haiku-4-5\nthinking: off\n---\nName the session.\n`,
);

const stub = `
const globalSettings = { sessions: { autoTitle: { refreshTurns: 4, timeoutSecs: 15, tokenBudget: 64 } } };
export const getAgentDir = () => ${JSON.stringify(agentDir)};
export const SettingsManager = { create: () => ({ getGlobalSettings: () => globalSettings }) };
export const buildSessionContext = (entries) => ({ messages: entries });
export const convertToLlm = (m) => m;
export const serializeConversation = () => "conversation";
`;
const stripped = stub + source
  .replace(/^import[\s\S]*?from "@earendil-works\/pi-coding-agent";$/m, "")
  .replace(/^@ts-nocheck$/m, "");
const temp = path.join(agentDir, "under-test.ts");
fs.writeFileSync(temp, stripped);
const { normalizeTitle, buildPrompt } = await import(temp);

assert.equal(normalizeTitle('  "Fix the flaky test."  '), "Fix the flaky test");
assert.equal(normalizeTitle("x".repeat(200)).length, 80);
assert.equal(normalizeTitle("   "), undefined);

const prompt = buildPrompt("hello", "/repo", "Old title", true, "instructions");
assert.match(prompt, /<cwd>\/repo<\/cwd>/);
assert.match(prompt, /<current_title>Old title<\/current_title>/);
assert.ok(!buildPrompt("hello", undefined, undefined, false, "i").includes("<cwd>"));

console.log("herdr-title-sync: ok");
