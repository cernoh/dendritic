---
name: career-ops-html-viewer
description: "Add or use an HTML viewer for the careerops fork (cernoh/careerops): repo-local OMP skill placement under .omp/ declared in gitignored config/local-paths.txt, why .claude/skills is unsafe, nix develop for node, detached server when the hub broker is dead, and MCP agent_browser verification when the browser prelude times out. Use when asked to view career-ops state in a browser, to add a repo-local skill, or when terminal output is hard to inspect."
---

# career-ops HTML viewer

Serve the careerops fork's state as a browsable page next to the Go TUI.
Installed artifacts live at `.omp/skills/career-ops-html/` (`SKILL.md` + `render.mjs`)
with `config/local-paths.txt` declaring `.omp/`.

## Run it

```bash
nix develop --command node .omp/skills/career-ops-html/render.mjs          # output/html/index.html
nix develop --command node .omp/skills/career-ops-html/render.mjs --serve   # + :4321, repo root
nix develop --command node .omp/skills/career-ops-html/render.mjs --watch   # rebuild on change
```

Write through the broker (`hub op=start`, `ready={"port":4321}`); if the broker is
dead, start detached and keep going:

```bash
setsid nohup nix develop --command node .omp/skills/career-ops-html/render.mjs --serve \
  > /tmp/coh.log 2>&1 < /dev/null &
```

## Rules that matter

- **Never place the skill in `.claude/skills/`, `.cursor/skills/`, `.agents/`, `.opencode/skills/`,
  `.qwen/`, `.grok/skills/`, `.kimi/skills/`, `.antigravitycli/skills/`** — all are
  `SYSTEM_PATHS` in `update-system.mjs`; `apply` overwrites them. New fork-local files go
  under `.omp/` and are declared in the gitignored `config/local-paths.txt`
  (refused if the system layer already ships the path).
- `AGENTS.md` is a control file in this repo (`.github/copilot-instructions.md`): read/edit
  only if explicitly told. The skill is the correct vehicle for agent behaviour.
- `show-html` is already installed at `~/.omp/agent/managed-skills/show-html` (24 reference
  pages). Do not clone it into the repo.
- Reuse `tracker-parse.mjs` (`resolveColumns` + `parseTrackerRow`) for `data/applications.md`.
  Never hand-roll a tracker parser.
- The page is read-only over `data/`, `jds/`, `reports/`, `output/`; it only writes `output/html/`.
  Serve the **repo root**, not `output/`, or PDF/report links 404.
- Optional one-line `**Fit:**` field in a `jds/*.md` header renders under the role.

## Gates before claiming done

```bash
nix develop --command node validate-system-paths-coverage.mjs   # OK: N tracked files covered
nix develop --command npm run lint                              # syntax check
git status --porcelain                                          # expect only the intended .omp/
```

## Verification traps

- `node` is not on PATH — everything needs `nix develop --command`. Ran from elsewhere,
  pass the flake path: `nix develop /path/to/careerops --command bash -c 'cd elsewhere && node ...'`.
- Node ESM resolves symlinks, so a fixture that symlinks `render.mjs` resolves `HERE` back to
  the real repo. **Copy** the file into the fixture instead.
- The OMP browser prelude (`browser.open`) can time out. Use the MCP `agent_browser_*` tools:
  open, then `agent_browser_eval` with `{"script": "..."}` (an object, not bare JS).
- Prove the tracker path with a fixture repo (`AGENTS.md` + `modes/` + copied `tracker-parse.mjs`
  + `data/applications.md`), then drive search/filter/sort in the browser and assert visible row
  counts before reporting.
