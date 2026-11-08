#!/usr/bin/env node
// Re-apply the local @valdo766hi/pi-lazy-skill-tool patches after any npm install.
//
// node_modules is gitignored, so every `npm install` (and every `pi update
// --extensions`) restores the pristine upstream files and the /skill:<name>
// regression comes back. This runs as `postinstall` for that reason: the same
// command that erases the patches puts them back.
//
// Both patches exist because pi 1.4.0 diverged from what 0.3.1 was written
// against. See ~/.pi/agent/AGENTS.md ("pi-lazy-loader and
// pi-lazy-skill-tool") for the full failure story.
//
//   node patches/pi-lazy-skill-tool.mjs           apply (idempotent)
//   node patches/pi-lazy-skill-tool.mjs --check   verify only; exit 1 if missing
//
// A missing anchor means upstream changed shape: nothing is written, the run
// says which patch went stale, and --check exits nonzero so a stale patch
// cannot pass silently.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pkg = join(root, "node_modules", "@valdo766hi", "pi-lazy-skill-tool", "src");
const checkOnly = process.argv.includes("--check");

const SRC_1 = "slash-command.ts";
const SRC_2 = "index.ts";

// Patch 1 — skill commands carry the resource root as baseDir.
//
// Pi expands /skill:<name> into a block whose first line is
// "References are relative to <skill dir>.", but in 1.4.0
// command.sourceInfo.baseDir is the RESOURCE ROOT (~/.pi/agent), not the skill
// directory. The snapshot built from the command registry therefore disagreed
// with every block pi produced, and guardSkillContext swapped real skill
// instructions for "[SKILL_UNREADABLE] Skill instructions are unreadable."
// The skill's own directory is the only baseDir that can match.
const PATCH_1 = {
	file: SRC_1,
	label: "slash-command.ts: baseDir from dirname(sourcePath)",
	anchor: `		const sourceBase = command.sourceInfo.baseDir;
		let baseDir = dirname(sourcePath);
		if (sourceBase) {
			baseDir = isAbsolute(sourceBase) ? sourceBase : resolve(cwd, sourceBase);
		}`,
	replacement: `		// pi 1.4 reports sourceInfo.baseDir as the resource root (~/.pi/agent), but a
		// skill block it expands says "References are relative to <skill dir>". The
		// snapshot must agree with the block, or guardSkillContext rejects it.
		const baseDir = dirname(sourcePath);`,
	verify: (text) => !/sourceInfo\.baseDir;/.test(text),
};

// Patch 2 — publish the snapshot even when the prompt rewrite fails.
//
// Pi wraps its skill catalog in <skills>…</skills> joined by single newlines, so
// 0.3.1's exact-anchor formatSkillsForPrompt() rewrite always misses and
// before_agent_start returns `failure`. That early return also skipped
// publishSnapshot, leaving the session_start command-registry snapshot live —
// the one carrying the wrong baseDir above. Publishing first makes the
// corrected snapshot the one the guard validates blocks against.
const PATCH_2 = {
	file: SRC_2,
	label: "index.ts: publishSnapshot before the failure return",
	anchor: `	if (result.failure) return undefined;
	publishSnapshot(state, snapshot);`,
	replacement: `	// [local patch] pi 1.4 breaks the anchored formatSkillsForPrompt rewrite, so
	// \`result.failure\` is the normal outcome for /skill:<name>. Publishing before
	// the early return keeps the corrected snapshot live instead of the stale
	// command-registry snapshot from session_start, which guardSkillContext
	// rejects as SKILL_UNREADABLE.
	publishSnapshot(state, snapshot);
	if (result.failure) return undefined;`,
	verify: (text) =>
		!/\tif \(result\.failure\) return undefined;\n\tpublishSnapshot\(state, snapshot\);/.test(
			text,
		),
};

let failed = false;

for (const patch of [PATCH_1, PATCH_2]) {
	const target = join(pkg, patch.file);
	let text;
	try {
		text = readFileSync(target, "utf8");
	} catch (error) {
		console.error(`pi-lazy-skill-tool patch: cannot read ${target}: ${error.message}`);
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

	// The replacement is itself the anchor of a partially applied tree? Only the
	// literal upstream text is patched; anything else is upstream drift.
	if (!text.includes(patch.anchor)) {
		console.error(
			`warn ${patch.label} — upstream anchor not found in ${patch.file}.`,
		);
		console.error("     Upstream @valdo766hi/pi-lazy-skill-tool changed shape;");
		console.error("     re-read the failure and update patches/pi-lazy-skill-tool.mjs.");
		failed = true;
		continue;
	}

	writeFileSync(target, text.replace(patch.anchor, patch.replacement));
	console.log(`fix  ${patch.label}`);
}

if (checkOnly && failed) {
	process.exit(1);
}
