---
name: wfinfo-ext-verification-traps
description: "Verify WFinfo-ext changes honestly: force real flake-check gate output (the \"running 0 flake checks\" non-pass), prove dashboard UI with a headless Brave tab, fix the .#dashboard Permission denied app, and never pkill the user's Brave or the eval-browser helper."
---

# WFinfo-ext verification traps (repo: /mnt/2tb-storage/wf-info-ext/WFinfo-ext)

## 1. `nix flake check` summary line is not proof

`running 0 flake checks ... all checks passed!` means the gate outputs were
already valid — Nix counts only checks it still has to build. It proves nothing
about the current tree.

Force real output per gate (do this before claiming the committed tree passes):

```bash
nix eval --json .#checks.x86_64-linux --apply 'builtins.attrNames'
# -> ["dashboard-format","dashboard-typecheck","dashboard-unit-tests"]
for g in dashboard-format dashboard-typecheck dashboard-unit-tests; do
  nix build --no-link -L --rebuild ".#checks.x86_64-linux.$g" 2>&1 | tail -12
done
```

Accept evidence only when the logs name the new files/tests: e.g.
`wfinfo-dashboard-unit-tests> ok | 42 passed | 0 failed` and a test name that
exists only in the changed sources. Note `nix flake check` skips aarch64; use
`--all-systems` for cross-system proof.

Paths can be relative with `nix build --no-link --rebuild`; `--rebuild` is what
defeats the cache.

## 2. `.#dashboard` app was broken by `toString`

`program = toString (pkgs.writeShellScriptBin name script)` yields the store
DIRECTORY, so `nix run .#dashboard` dies with
`error: unable to execute '/nix/store/...-wfinfo-dashboard': Permission denied`.
Correct: `program = "${pkgs.writeShellScriptBin name script}/bin/<name>";` plus
`meta.description = "…";` (silences the "lacks attribute 'meta'" warning).

## 3. Long-running server without `hub`/`nohup`

`hub op start` fails here (broker ENOENT) and bash blocks `nohup`/`&`. Start the
server as a background bash job:

```bash
nix develop -c deno run -A dashboard/src/main.ts   # env: PORT, WFINFO_DATA_DIR
```

Run it with `async: true`, then poll `curl -s -o /dev/null -w '%{http_code}'`.
Use `PORT=87xx` (8000 is often busy) and an isolated `WFINFO_DATA_DIR` with
symlinks to `tessdata/`, `market_items.json`, `market_data.json` so smoke scans
never touch the real `~/.config/WFInfo`.

## 4. Dashboard UI proof: launch Brave explicitly

The default CDP attach and the agent-browser MCP both time out (30 s). A
spawned headless Brave works:

```js
const tab = await browser.open({
  name: "wfdash",
  url: "http://localhost:8799/scan",
  app: { path: "/etc/profiles/per-user/davr/bin/brave",
         args: ["--headless=new", "--no-first-run", "--no-default-browser-check", "--disable-gpu"] },
  viewport: { width: 1280, height: 900 },
});
await tab.waitForSelector("#wf-scan-button");
await tab.evaluate(`(() => { document.getElementById("wf-scan-button").click(); return true; })()`);
```

`tab.click(sel)` times out on these pages; `tab.evaluate(... click())` works.
`tabwaitFor` on an expression also times out around 29 s — poll from the eval
kernel with `tab.run("await new Promise(r => setTimeout(r, 3000))")` instead.
Release tabs with `browser.close({ name })`.

## 5. NEVER pkill the user's browser processes

- `.brave-wrapped` / brave desktop session = the user's own browsing.
- `chromium ... --remote-debugging-port=9224 --user-data-dir=/tmp/chrome-brave-profile`
  = the eval-browser tool's managed helper; killing it breaks browser tooling.

Clean up only your own patterns (`deno run -A dashboard/src/main.ts`,
`wfinfo-dashboard`, `brave --headless` spawns from `profiles/per-user/davr/bin/brave`),
and confirm with `ps -o pid=,etime=,comm= -p <pid>` that long-lived PIDs predate
your session before touching anything.

## 6. PR mechanics for this remote

`cernoh/WFinfo-ext` has GitHub issues DISABLED: no `Closes #N`; write a complete
PR body and tag the title `... (#<number>)` after `gh pr create`. Branch from
`origin/master` explicitly (`git checkout -b <name> origin/master`) — the
checkout is often on a detached HEAD. Deno gates run via `nix develop -c deno …`;
`deno fmt` rewrites files in place, so run it before `deno fmt --check`.
