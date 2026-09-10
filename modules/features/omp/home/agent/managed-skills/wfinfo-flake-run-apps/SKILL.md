---
name: wfinfo-flake-run-apps
description: "Add or fix nix run .#app entrypoints in the WFinfo-ext flake (dev-server apps, live reload, working-tree vs store copy), and verify long-running servers when the hub broker is down. Use when adding a flake app to this repo, when nix run .#dashboard-style apps fail with \"Permission denied\", or when a dev server must be proven live with an edit."
---

# WFInfo-ext flake run-apps (WFinfo-ext repo, flake.nix)

## Traps learned
- `program = toString (pkgs.writeShellScriptBin name script)` is WRONG: `toString` yields the
  derivation output DIRECTORY, and `nix run` then fails with
  `error: unable to execute '/nix/store/…-<name>': Permission denied`.
  Correct form: `program = "${pkgs.writeShellScriptBin name script}/bin/<name>";`.
- `nix run .` copies the flake source into the READ-ONLY store (tracked files only; untracked
  files are invisible). A `--watch` dev server pointed at the store copy can never reload. A
  `dev` app must resolve `dashboard/` from the working tree, e.g.
  `root="${WFINFO_DASHBOARD_ROOT:-$PWD}"`, test `-f "$root/dashboard/src/main.ts"`, then
  `cd "$root/dashboard" && exec deno task dev "$@"` (rc 1 with a clear message otherwise).
- `nixfmt` 1.4.0 formats files IN PLACE (stdout stays empty) and this repo is NOT
  nixfmt-RFC-formatted and has no nix formatter gate (flake `checks` are dashboard-only, no
  `.github/workflows`). Never run bare `nixfmt flake.nix`; if you do, `git checkout -- flake.nix`
  and re-apply the hand-styled edits to keep the diff minimal.
- `nix flake check` warns `app ... lacks attribute 'meta'`; `meta.description = "…";` inside each
  app attr silences it.
- Repo style: 2-space indent, `apps = forAllSystems (pkgs: { … })`, no Nix app args passthrough
  beyond `"$@"`.

## Add a run app (recipe)
1. Edit `flake.nix`: add the app inside `apps = forAllSystems (pkgs: { … })`, plus a header
   comment line and a `shellHook` echo line.
2. Docs (DOX closeout): `dashboard/README.md` quick start, `dashboard/AGENTS.md` Work Guidance,
   root `AGENTS.md` Verification list. Keep STE prose.
3. Prove it:
   - `nix eval --raw .#apps.x86_64-linux.<app>.program` → must end in `/bin/<name>`.
   - `nix eval --raw .#apps.aarch64-linux.<app>.program` → cross-system eval.
   - `nix flake check` → all checks passed.
   - Real run, see below.
4. Branch + PR: this remote has ISSUES DISABLED, so no `Closes #N`. Push, `gh pr create
   --base master`, then `gh pr edit <n> --title "<title> (#<n>)"`.

## Verify a long-running server without hub
`hub op start` fails here with `Failed to start daemon broker: connect ENOENT
/home/davr/.omp/run/daemons/<scope>/broker.sock`, and the bash tool blocks `nohup`/`&`. Drive the
process from the eval kernel (JS) instead:

```js
const p = Bun.spawn(["nix", "run", ".#dev"], {
  cwd: repo, env: { ...process.env, PORT: "8765" }, stdin: "ignore",
  stdout: "pipe", stderr: "pipe",
});
let out = ""; const dec = new TextDecoder();
(async () => { for await (const c of p.stdout) out += dec.decode(c); })();
(async () => { for await (const c of p.stderr) out += dec.decode(c); })();
// poll: await small sleep loop until out.includes("listening: http://localhost:8765")
// prove reload: Bun.write a marker string into dashboard/src/lib/view.ts, poll until
//   out.includes("Restarting") AND fetch("/recent") contains the marker; then Bun.write the
//   ORIGINAL text back, poll until the marker is gone, and assert `git diff -- <file>` is "".
// stop: Bun.spawnSync(["pkill","-f","src/main.ts"]); p.kill(); then confirm
//   pgrep -af src/main.ts prints nothing.
```

Parse ports/status: use 8765+ because 8000 is often busy. Screenshot/visual checks are NOT
available on this host (no runnable Chromium) — HTTP status + byte counts + DOM string matching
are the accepted evidence.

## Related
`wfinfo-dashboard` (user skill) covers data-file quirks, gates and the app itself; read it before
touching `dashboard/src`.
