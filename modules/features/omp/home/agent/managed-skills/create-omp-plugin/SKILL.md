---
name: create-omp-plugin
description: "Create OMP plugins with custom tools using the ExtensionAPI — package.json structure, index.ts pattern, registerTool, and install via omp plugin link"
---

# Creating an OMP Plugin

OMP plugins register custom tools via the extension API. Minimal structure:

## Directory layout
```
~/.omp/plugins/my-plugin/
  package.json
  index.ts
  skills/           # optional
    my-plugin.md
```

## package.json
```json
{
  "name": "omp-my-plugin",
  "version": "0.1.0",
  "description": "...",
  "license": "MIT",
  "omp": {
    "extensions": ["./index.ts"],
    "skills": ["skills"]
  },
  "peerDependencies": {
    "@oh-my-pi/pi-coding-agent": "*"
  }
}
```

## index.ts
```typescript
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function myExtension(pi: ExtensionAPI) {
  pi.setLabel("My Plugin");
  const z = pi.zod;

  pi.registerTool({
    name: "my_tool",
    label: "My Tool",
    description: "What it does and when to use it.",
    parameters: z.object({
      arg: z.string().describe("Parameter description"),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      // ctx.cwd is the current working directory
      return {
        content: [{ type: "text", text: "Result text" }],
        // Optional structured data for UI rendering:
        // details: { key: "value" },
        // Optional error flag:
        // isError: true,
      };
    },
  });
}
```

## Install
```bash
omp plugin link ~/.omp/plugins/my-plugin   # local dev
omp plugin list                             # verify it appears
```

## Key API surface
- `pi.setLabel(name)` — display name in plugin list
- `pi.zod` — Zod instance for parameter schemas
- `pi.registerTool({ name, label, description, parameters, execute })` — register a tool
- `pi.on(event, handler)` — lifecycle hooks: `session_start`, `before_agent_start`, etc.
- `execute(toolCallId, params, signal, onUpdate, ctx)` — `ctx.cwd` for working directory

## Reference implementations
- **Minimal**: `~/.omp/plugins/direnv/` (313 lines, 2 tools, event hooks)
- **Complex**: `~/.omp/plugins/node_modules/pi-interactive-shell/` (full PTY management)

## Notes
- Tools appear in the agent's tool list after `omp plugin link` + session restart
- `execFileSync` preferred over `execSync` for safety (no shell injection)
- Return `isError: true` for tool failures; the agent sees the error text
- Skills in `skills/` dir are auto-discovered and surfaced to the agent
