#!/usr/bin/env node
// Preserve the model-specific UTC peak exclusion needed by this OpenCode Go
// route. Upstream policy rules currently filter whole providers, but all three
// configured models belong to the same provider.
//
// node patches/pi-auto-router.mjs           apply (idempotent)
// node patches/pi-auto-router.mjs --check   verify only; exit 1 if missing

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const checkOnly = process.argv.includes("--check");

const patches = [
  {
    file: "src/types.ts",
    label: "types.ts: exclude-target policy type",
    anchor: 'type: "force-tier" | "prefer-provider" | "exclude-provider" | "force-billing" | "force-constraint";',
    replacement: 'type: "force-tier" | "prefer-provider" | "exclude-provider" | "exclude-target" | "force-billing" | "force-constraint";',
    verify: (text) => text.includes('"exclude-target"') && text.includes("excludeTargets?: Array<"),
  },
  {
    file: "src/types.ts",
    label: "types.ts: exact excluded target hint",
    anchor: "  excludeProviders?: string[];\n  preferProviders?: string[];",
    replacement: "  excludeProviders?: string[];\n  excludeTargets?: Array<{ provider: string; modelId: string }>;\n  preferProviders?: string[];",
    verify: (text) => text.includes("excludeTargets?: Array<{ provider: string; modelId: string }>;"),
  },
  {
    file: "src/types.ts",
    label: "types.ts: model id in policy config",
    anchor: "  provider?: string | string[];\n  billing?: BillingModel;",
    replacement: "  provider?: string | string[];\n  modelId?: string;\n  billing?: BillingModel;",
    verify: (text) => text.includes("  modelId?: string;\n  billing?: BillingModel;"),
  },
  {
    file: "src/policy-engine.ts",
    label: "policy-engine.ts: merge excluded targets",
    anchor: "    excludeProviders: incoming.excludeProviders ?? base.excludeProviders,\n    preferProviders: incoming.preferProviders ?? base.preferProviders,",
    replacement: "    excludeProviders: incoming.excludeProviders ?? base.excludeProviders,\n    excludeTargets: incoming.excludeTargets ?? base.excludeTargets,\n    preferProviders: incoming.preferProviders ?? base.preferProviders,",
    verify: (text) => text.includes("excludeTargets: incoming.excludeTargets ?? base.excludeTargets,"),
  },
  {
    file: "src/policy-engine.ts",
    label: "policy-engine.ts: build exclude-target hint",
    anchor: `    case "force-billing":\n      if (c.billing) hints.enforceBilling = c.billing;`,
    replacement: `    case "exclude-target":\n      if (typeof c.provider === "string" && c.provider.trim() && typeof c.modelId === "string" && c.modelId.trim()) {\n        hints.excludeTargets = [{ provider: c.provider, modelId: c.modelId }];\n      }\n      break;\n    case "force-billing":\n      if (c.billing) hints.enforceBilling = c.billing;`,
    verify: (text) => text.includes('case "exclude-target":'),
  },
  {
    file: "index.ts",
    label: "index.ts: filter exact targets",
    anchor: `        // Apply billing model enforcement\n        if (effectiveHints.enforceBilling) {`,
    replacement: `        // Apply exact model exclusions (provider-level exclusions are too broad\n        // when multiple routed models share one provider).\n        if (effectiveHints.excludeTargets && effectiveHints.excludeTargets.length > 0) {\n          const excludeSet = new Set(effectiveHints.excludeTargets.map((t) => getTargetKey(t)));\n          filteredHealthy = filteredHealthy.filter((t) => !excludeSet.has(getTargetKey(t)));\n          ctx.availableTargets = filteredHealthy;\n        }\n        // Apply billing model enforcement\n        if (effectiveHints.enforceBilling) {`,
    verify: (text) => text.includes("effectiveHints.excludeTargets.map((t) => getTargetKey(t))"),
  },
  {
    file: "src/display.ts",
    label: "display.ts: show excluded targets in explanations",
    anchor: '  if (hints.excludeProviders?.length) parts.push(`exclude=[${hints.excludeProviders.join(",")}]`);',
    replacement: '  if (hints.excludeProviders?.length) parts.push(`exclude=[${hints.excludeProviders.join(",")}]`);\n  if (hints.excludeTargets?.length) parts.push(`exclude-targets=[${hints.excludeTargets.map((t) => `${t.provider}/${t.modelId}`).join(",")} ]`);',
    verify: (text) => text.includes("hints.excludeTargets?.length"),
  },
  {
    file: "index.ts",
    label: "index.ts: report excluded targets in reasoning",
    anchor: '        if (strategyHints.excludeProviders?.length) stratParts.push(`exclude=[${strategyHints.excludeProviders.join(",")}]`);',
    replacement: '        if (strategyHints.excludeProviders?.length) stratParts.push(`exclude=[${strategyHints.excludeProviders.join(",")}]`);\n        if (strategyHints.excludeTargets?.length) stratParts.push(`exclude-targets=[${strategyHints.excludeTargets.map((t) => `${t.provider}/${t.modelId}`).join(",")}]`);',
    verify: (text) => text.includes("strategyHints.excludeTargets?.length"),
  },
  {
    file: "index.ts",
    label: "index.ts: persist excluded targets in strategy trace",
    anchor: "          excludeProviders: strategyHints.excludeProviders,\n          enforceBilling: strategyHints.enforceBilling,",
    replacement: "          excludeProviders: strategyHints.excludeProviders,\n          excludeTargets: strategyHints.excludeTargets,\n          enforceBilling: strategyHints.enforceBilling,",
    verify: (text) => text.includes("excludeTargets: strategyHints.excludeTargets,"),
  },
  {
    file: "index.ts",
    label: "index.ts: preserve exclusions during constraint fallback",
    anchor: "        : (solved.candidates.length > 0 ? solved.candidates : healthy);",
    replacement: "        : (solved.candidates.length > 0 ? solved.candidates : filteredHealthy);",
    verify: (text) => text.includes("solved.candidates.length > 0 ? solved.candidates : filteredHealthy"),
  },
];

let failed = false;
for (const patch of patches) {
  const file = join(root, "node_modules", "pi-auto-router", patch.file);
  let text;
  try {
    text = readFileSync(file, "utf8");
  } catch (error) {
    console.error(`FAIL ${patch.label} — cannot read ${file}: ${error.message}`);
    failed = true;
    continue;
  }

  if (patch.verify(text)) {
    console.log(`${checkOnly ? "ok  " : "keep"} ${patch.label}`);
    continue;
  }
  if (checkOnly) {
    console.error(`FAIL ${patch.label} — patch is NOT applied`);
    failed = true;
    continue;
  }
  if (!text.includes(patch.anchor)) {
    console.error(`FAIL ${patch.label} — upstream anchor not found in ${patch.file}`);
    failed = true;
    continue;
  }

  writeFileSync(file, text.replace(patch.anchor, patch.replacement));
  console.log(`fix  ${patch.label}`);
}

if (failed) process.exit(1);
