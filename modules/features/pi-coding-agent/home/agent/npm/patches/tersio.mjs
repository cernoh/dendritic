#!/usr/bin/env node
// Re-apply the local tersio patch after any npm install.
//
// node_modules is gitignored, so every `npm install` restores pristine upstream
// tersio and `tersio doctor` goes back to reporting a phantom 150-file fault.
// This runs as `postinstall` for that reason.
//
//   node patches/tersio.mjs           apply (idempotent)
//   node patches/tersio.mjs --check   verify only; exit 1 if missing
//
// The fault: `tersio doctor` and the dashboard compare every host that reads as
// installed against a *copied* add-on tree, but pi can be installed in two
// mutually exclusive shapes and only one of them has a tree:
//
//   package mode — pi's settings.json lists `npm:@krtclcdy/tersio` (this repo's
//                  shape, needed for the `!extensions/server.ts` filter), so the
//                  add-ons load from node_modules and nothing is written to
//                  ~/.pi/agent/extensions;
//   tree mode    — `tersio install --host pi` copies 150 files into
//                  ~/.pi/agent/extensions. Upstream warns when both exist:
//                  "pi also has a tersio package … or both copies load".
//
// With package mode the tree comparison has nothing to compare, so doctor
// reports "Add-on tree content: 150 declared files not written" as an issue and
// tells you to run `tersio doctor --fix extensions` — which does nothing,
// because that repair deliberately skips a tree where zero files are present
// (`present === 0` in doctor-fix.js). A row whose printed remedy cannot clear it
// is the bug this patch fixes, not a state to repair.
//
// The guard is "package install with no tree file on disk", not "package
// install", so a genuinely half-written tree is still caught: once one declared
// file exists the comparison runs as before. omp keeps its check — its plugin
// directory is the package itself, so every declared file is present there.
//
// Verified 2026-11-13 against tersio 2.25.20 (latest on npm): before, doctor
// reported 13 checks with 2 missing; after, 13 checks with 0 missing. See
// ~/.pi/agent/AGENTS.md ("Extension version pins" → tersio) for the install
// model.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const TERSIO = join(root, "node_modules", "@krtclcdy", "tersio", "dist", "cli");
const checkOnly = process.argv.includes("--check");

const GUARD = `        // [local patch] Package-installed host, no tree file on disk: the
        // add-ons load from its npm package, so there is nothing to compare —
        // and a half-written tree still gets caught, since one present file
        // puts the comparison back.
        if (
            host.via === "package" &&
            host.id !== "dsh" &&
            treeFilesFor(treeId).every((rel) => !existsSync(path.join(base, ...rel.split("/"))))
        )
            continue;`;

// doctor.js — the per-file tree comparison ("Per-host add-on files").
const DOCTOR_COMPARE = {
	file: join(TERSIO, "doctor.js"),
	label: "doctor.js: tree comparison skip for package-installed pi",
	anchor: `        const treeId = host.id === 'omp' ? 'opencode' : host.id;
        const base = treeBaseFor(host);
        let onDisk = new Set(hostTreeFiles(base).filter((rel) => path.extname(rel) !== '.js'));`,
	replacement: `        const treeId = host.id === 'omp' ? 'opencode' : host.id;
        const base = treeBaseFor(host);
${GUARD}
        let onDisk = new Set(hostTreeFiles(base).filter((rel) => path.extname(rel) !== '.js'));`,
	verify: (text) => text.includes("[local patch] Package-installed host"),
};

// doctor.js — the "Add-on tree content" issue row.
const DOCTOR_UNWRITTEN = {
	file: join(TERSIO, "doctor.js"),
	label: "doctor.js: unwritten-tree issue skip for package-installed pi",
	anchor: `            const treeId = host.id === 'omp' ? 'opencode' : host.id;
            const base = treeBaseFor(host);
            for (const rel of treeFilesFor(treeId)) {`,
	replacement: `            const treeId = host.id === 'omp' ? 'opencode' : host.id;
            const base = treeBaseFor(host);
${GUARD.replace(/^ {8}/gm, "            ")}
            for (const rel of treeFilesFor(treeId)) {`,
	verify: (text) => text.includes("[local patch] Package-installed host", text.indexOf("unwrittenTreeFiles")),
};

// host-tree.js — the same comparison behind the dashboard's diagnosis.
const HOST_TREE = {
	file: join(TERSIO, "host-tree.js"),
	label: "host-tree.js: dashboard tree comparison skip for package-installed pi",
	anchor: `        const treeId = host.id === 'omp' ? 'opencode' : host.id;
        const base = host.id === 'omp' ? pluginExtDir : hostExtensionsDir(host.id);
        let onDisk = new Set(hostTreeFiles(base).filter((rel) => path.extname(rel) !== '.js'));`,
	replacement: `        const treeId = host.id === 'omp' ? 'opencode' : host.id;
        const base = host.id === 'omp' ? pluginExtDir : hostExtensionsDir(host.id);
${GUARD}
        let onDisk = new Set(hostTreeFiles(base).filter((rel) => path.extname(rel) !== '.js'));`,
	verify: (text) => text.includes("[local patch] Package-installed host"),
};

let failed = false;

for (const patch of [DOCTOR_COMPARE, DOCTOR_UNWRITTEN, HOST_TREE]) {
	let text;
	try {
		text = readFileSync(patch.file, "utf8");
	} catch (error) {
		console.error(`tersio patch: cannot read ${patch.file}: ${error.message}`);
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
		console.error(`warn ${patch.label} — upstream anchor not found.`);
		console.error("     Upstream tersio changed shape; re-read the doctor failure and update");
		console.error("     patches/tersio.mjs rather than guessing at the new code.");
		failed = true;
		continue;
	}

	writeFileSync(patch.file, text.replace(patch.anchor, patch.replacement));
	console.log(`fix  ${patch.label}`);
}

if (checkOnly && failed) {
	process.exit(1);
}
