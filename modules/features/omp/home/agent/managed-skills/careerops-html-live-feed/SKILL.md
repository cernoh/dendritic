---
name: careerops-html-live-feed
description: "Add or debug the live activity feed in the career-ops HTML viewer (.omp/skills/career-ops-html/): append-only JSONL events vs atomic state file for concurrent writers, the emitted-script newline trap that silently kills the page script, poller counter reset-after-paint, and browser verification that accounts for tab freezing."
---

# career-ops HTML viewer — live activity feed

Turns the fork-local snapshot page (`.omp/skills/career-ops-html/render.mjs`) into a page
that shows what an agent is doing *while* it works. Use when asked to "show what you're
doing live", to make a long agent run observable, or when the page renders but never
updates.

`web/` is a separate track — do not touch it. The viewer lives under `.omp/`, declared in
`config/local-paths.txt`, so `update-system.mjs apply` never overwrites it. Keep it
untracked (matches how it is installed).

## Two files, split by writer

| File | Writer | Why |
|---|---|---|
| `output/html/activity.jsonl` | everyone, `appendFileSync` | O_APPEND makes small concurrent appends safe — no lock needed. 12 parallel workers logged into one feed without a lost event. |
| `output/html/activity.json` | one caller | headline / phase / counters. Written atomically (temp file + `renameSync`) so a poller never reads a half-written file. |

A single read-modify-write JSON file **loses events** under concurrent writers. That is the
whole reason for the split.

`activity.mjs` commands: `log "<msg>" [--tag X] [--level info|ok|warn|err] [--detail ...] [--done N] [--total M]`,
`phase "<name>"`, `reset`, `show [--json]`. Every value is one argv token, so quote multi-word text.
Give spawned workers the command in their brief; they then report progress themselves.

## Trap 1 — the emitted-script newline (silent, total)

`render.mjs` builds the page inside a **template literal**. `\n` in that literal becomes a
real newline in the emitted `<script>`, so `raw.split('\n')` ships as `split('` + newline + `')`
— an unterminated string. The browser drops the **entire** script block: the page looks
correct and never updates. Server-side writes `'\\n'` instead.

Guard it in `build()` so it can never ship again:

```js
for (const m of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) {
  try { new Function(m[1]); }
  catch (err) { throw new Error('emitted <script> does not parse: ' + err.message); }
}
```

## Trap 2 — a frozen feed that looks healthy

The poller must reset `misses` **after every DOM write**, not before the first one.
Reset it early and a throw mid-paint (a missing node) resets the counter every cycle:
`misses` never reaches the threshold and the dot stays green over a dead feed.

```js
el('live-list').innerHTML = …;      // last paint
misses = 0;                          // only after every write landed
```

## Verification the tab will actually show you

The harness freezes idle tabs, so a 2 s `setInterval` appears dead between tool calls —
evals return in under 2 s and the tick never fires. **Wait inside the eval**, then read the DOM:

```js
(async () => { await new Promise(r => setTimeout(r, 3000));
  return { dot: document.getElementById('livedot').className,
           rows: document.querySelectorAll('#live-list .ev').length }; })()
```

To prove the failure signal, force it: remove `#live-list` (the *last* paint before the
counter reset — the strictest case), sleep 6 s, assert the dot reads `livedot off` and its
`title` carries the real error. Reload and assert `livedot on` with rows present.

Confirm the **served** file has the fixed ordering by offset — and do not let
`indexOf('misses = 0;')` match the `let misses = 0;` declaration:

```bash
node -e "const h=require('fs').readFileSync('output/html/index.html','utf8');
console.log(h.indexOf(\"el('live-list').innerHTML\") < h.indexOf('misses = 0; // only after every write landed'))"
```

Serve the **repo root** (`--serve`), never `output/`, or PDF and report links 404. The
poller fetches `activity.json` and `activity.jsonl` relative to the page, so both must be
served; add `'.jsonl': 'application/x-ndjson'` to the `TYPES` map. `node` is not on PATH in
this repo — call it by absolute path or through `nix develop --command`.

## Gates before saying done

```bash
npm run lint                                  # syntax check
node validate-system-paths-coverage.mjs       # OK: N tracked files covered
git status --porcelain                        # expect only the intended .omp/
```
