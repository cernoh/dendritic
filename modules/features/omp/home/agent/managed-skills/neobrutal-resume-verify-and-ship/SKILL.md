---
name: neobrutal-resume-verify-and-ship
description: "Verify and ship issue-linked PRs in the neobrutal-resume-vercel repo: merged-tree gate commands, gh merge without doubled PR tags, and catching subagents that edit the main checkout instead of their worktree (stale dist lies about the deployed bundle)"
---

# Verify and ship in neobrutal-resume-vercel

Repo: `/mnt/2tb-ext4/neobrutal-resume-vercel` (GitHub `cernoh/neobrutal-resume-vercel`).
React 18 + Vite + Tailwind resume site on Vercel; CI (`ci`) and a Typst check (`cv-fresh`) run on every PR.

## Toolchain (none of it is on PATH)

| Need | Command |
|---|---|
| node/npm/npx (24.x) | `nix shell nixpkgs#nodejs -c <cmd>` |
| deno 2.9, typst 0.15.1, prettierd | `nix develop -c <cmd>` |
| chromium for screenshots | `nix shell nixpkgs#chromium -c chromium` |
| PDF text extraction | `nix shell nixpkgs#poppler-utils -c pdftotext -layout <pdf> -` |

Git identity is unset: commit with `git -c user.name=cernoh -c user.email=zoiny@outlook.com commit`.

## The gate, and its traps

```
npm ci
npm run lint                                   # exit 0 on a clean checkout
npx tsc --noEmit -p tsconfig.app.json          # BARE `npx tsc --noEmit` IS A NO-OP
npx tsc --noEmit -p tsconfig.node.json         #  root tsconfig.json is solution-style ("files": [])
npm run build
nix develop -c ./scripts/build-cv.sh --check   # byte-compares public/cv/*.pdf with a fresh compile
```

- `eslint .` also lints `./.worktrees/**` (flat config ignores only `dist`), so a local lint with agent
  worktrees present reports their files. CI on a clean checkout is the real signal.
- `node_modules` is deno-managed in the user's checkout (`.deno/` present). `npm ci` replaces it; restore
  the user's shape afterwards with `nix develop -c deno install` (leaves `deno.lock` untouched when in sync).

## Merging so history stays single-tagged

`gh pr` titles here end with `(#<pr-number>)` (repo convention), and GitHub's squash merge then appends the
number *again* if the PR title is used verbatim:

```
gh pr merge <n> --squash --delete-branch \
  --subject "type(scope): summary (#<n>)"
```

Pass `--subject` on every merge — otherwise the commit reads `... (#68) (#68)`.

## Verify subagent work on the merged tree, never on the claim

1. Fetch and diff the branch: `git diff --stat main...origin/<branch>` and read the hunks for the files the
   task owned. Reject out-of-scope files.
2. Merge only when `gh pr checks <n>` shows `ci`/`cv-fresh` pass.
3. After merging, rebuild and re-check on `main` yourself; the PR's own evidence is the agent's claim.

## TRAP: a subagent edits the MAIN checkout instead of its worktree

Seen twice (a `Header.tsx` edit that dropped a closing `</div>`; a stray `index.css` edit). Symptoms and
diagnosis:

- `vite build` fails with `Unexpected token` pointing at a **main-checkout** path, or
- the browser shows *old* data (e.g. an uncapped list) because the failed build left a stale `dist/`.
- Diagnose: `git status --short` in the main checkout, then `git diff -- <file>`; also confirm `dist/` mtime
  is newer than the merge commit before trusting anything rendered from it.

Repair: `git checkout -- <file>` (the committed state is fine — CI was green), then rebuild and re-verify.
Do not run `git clean -fd` blindly; check `git status --short` first — if it prints nothing there is nothing
to clean.

## Browser verification recipes

The harness `browser` prelude times out here; `hub`'s process broker is also dead
(`Failed to start daemon broker`). Use detached preview servers plus the mounted agent-browser MCP:

```
cd <worktree> && npm ci && npm run build
setsid nohup nix shell nixpkgs#nodejs -c npx vite preview --port <unique> --strictPort \
  >/tmp/preview-<port>.log 2>&1 < /dev/null &
sleep 6; curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:<port>/
```

MCP tools (write JSON args to the `xd://` paths): `mcp__agent_browser_open` (`{"url": ...}`),
`mcp__agent_browser_eval` (`{"script": "<js>"}`, returns the JSON-stringified result),
`_press`, `_screenshot`, `_close` (`{"all": true}`).

The MCP window size is fixed and `extraArgs: ["--window-size=..."]` is ignored on a reused browser, so
measure narrow layouts with a same-origin iframe inside `eval`:

```js
const f = document.createElement('iframe');
f.style.cssText = 'position:fixed;left:-9999px;width:375px;height:812px;border:0';
f.src = '/'; document.body.appendChild(f); await new Promise(r => f.onload = r);
await new Promise(r => setTimeout(r, 3000));           // let react-query settle
const d = f.contentDocument, el = d.documentElement;
const small = [...d.querySelectorAll('a,button')].filter(e => {
  const r = e.getBoundingClientRect(); return r.width < 44 || r.height < 44;
});
const sc = [...d.querySelectorAll('div')].find(e =>
  e.scrollHeight > e.clientHeight + 4 && getComputedStyle(e).overflowY !== 'visible');
if (sc) { sc.scrollTop = sc.scrollHeight; await new Promise(r => setTimeout(r, 700)); }
const dock = d.querySelector('.ios-dock').getBoundingClientRect();
const foot = d.querySelector('footer .ios-inset-panel').getBoundingClientRect();
// report: overflow = el.scrollWidth - el.clientWidth, small.length, dock.top - foot.bottom
```

Screenshots at an exact width (viewport-sized, so scroll for lower sections):
`chromium --headless=new --no-sandbox --disable-gpu --hide-scrollbars --virtual-time-budget=9000
--window-size=375,812 --screenshot=/tmp/shot.png http://127.0.0.1:<port>/`

Inspect any image with the read tool — `read("/tmp/shot.png?q=<question>")` returns a vision-model answer
without needing image input support. Treat its prose as a hint, not proof: it has reported a section label
"on the wallpaper" when the label in fact sat on a linen chip, and called the 1280 layout single-column when
it was above-the-fold only. Confirm with computed styles / bounding rects from `eval`.

## Repo facts worth not re-deriving

- `src/components/ui/**` and `hooks/` are gone (deleted as scaffolding); nothing imports them.
- `public/cv/junior-software-engineer.pdf` and `public/cv/it-technician.pdf` are generated by
  `cv/*.typ` + `scripts/build-cv.sh` with `--ignore-system-fonts --creation-timestamp 0`; CI pins typst
  0.15.1, so byte comparison holds across machines. Header CTA → SWE variant, dock → IT variant.
- Design system lives in `src/index.css` + `AGENTS.md`: elevation `.ios-elev-surface|raised|inset|pressed`,
  type tiers `.ios-heading|subheading|body|meta`, secondary text `ios.textSecondary` `#636366` (AA-measured).
- `AGENTS.md` is the repo's contract file for agents; keep it accurate when commands or layout change.
