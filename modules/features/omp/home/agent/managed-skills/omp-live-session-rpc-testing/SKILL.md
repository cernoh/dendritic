---
name: omp-live-session-rpc-testing
description: "Prove an omp extension, custom tool, or interactive bridge in a live session over omp --mode rpc: the JSONL harness, waiting for idle instead of guessing, the essential-vs-discoverable tool trap, the grill_form round endpoints, verifying a hidden skill's command, and the failure modes that cost real debug cycles"
---

# Proving an omp extension in a live session

A `omp -p` run exits after one turn, so it cannot prove anything that needs a second turn: an injected message, a queued answer, an HTTP bridge. Drive a real session over RPC instead. Verified 2026-09-15 while building `render_html`, `grill_form`, and `grill_finish` in `cernoh/dendritic`.

## The harness

`omp --mode rpc` speaks newline-delimited JSON: commands on stdin, frames on stdout. Python 3 is often absent on NixOS, so run the driver through nix.

```bash
omp --mode rpc --no-session --auto-approve --model @smol   # child, from python
nix shell nixpkgs#python3 --command python3 harness.py
```

Driver skeleton (stdlib only, no client package needed):

- spawn the child with `stdin=PIPE, stdout=PIPE, text=True, bufsize=1`; read stdout in a daemon thread appending to a list.
- send `{"id": "...", "type": "prompt", "message": "..."}`; frames worth matching are `{"type":"response","command":"prompt","success":true}` (accepted, **not** finished) and `{"type":"agent_end","isTerminal":true}` (turn finished).
- set `BROWSER=/bin/true` and `PI_NO_TITLE=1` in the child env, or a tool that opens a page will pop a window and RPC mode will burn a model call on a session title.
- scan frames from a monotonic cursor, never from index 0, so a later `wait_for` does not re-match an earlier turn's frame.

`hub start` is the usual way to hold the child, but it fails when the omp broker daemon is down (`connect ENOENT .../broker.sock` after 10s). Nothing in the probe needs the hub: spawn the child from the python driver and drop the hub when the broker is dead.

## Wait for idle, not for a frame

`agent_end` can arrive for an earlier turn than the one you are waiting on, and a late `agent_end` from the first turn makes you think the second finished. Sending the next prompt then fails with:

```json
{"command":"prompt","success":false,"error":"Agent is already processing. Use steer() or followUp() to queue messages, or wait for completion."}
```

Two fixes, use both:

1. After a submit or any injected work, poll `{"type":"get_state"}` until `data.isStreaming` is false, then sleep ~1.5s so maintenance settles.
2. Wrap every prompt in a retry: on `success:false`, sleep 10-12s and resend, up to about eight attempts. A cheap model on a synthetic prompt wanders, and the retry is what makes the harness deterministic.

## Assert on the bridge, not on the model

Split the checks. Tool-side behaviour (HTTP status, files written, page markup, page state) is deterministic and worth asserting strictly. Model compliance on a synthetic prompt is not: a cheap model (`@smol`) happily calls `read` instead of the tool you asked for, or continues the loop you told it to continue.

- Prefer several short prompts over one long one, and phrase the tool request exactly like the prompt that already worked.
- Keep the synthetic content away from files left by earlier runs; a stale `/tmp/<topic>.md` from a previous attempt is enough for the model to burn a turn "investigating" it.
- Assert the tool call itself (`"toolName":"grill_finish"` in the frames) rather than the assistant's prose.

## The grill_form bridge, concretely

Verified 2026-09-17 driving `skill://wayfinder` end to end in `cernoh/dendritic`: a fresh session read the skill, called `grill_form` with a 7-question round, the POST landed, and the answers came back as the next user message.

- The tool result text carries the page URL and `Environment: <dir>` (a `<tmpdir>/omp-html-env-*` folder). Match `Environment: (/[^\s]+)`; the model also echoes that phrase in its prose, so an unanchored `(\S+)` match grabs a `<dir>` placeholder and the round file lookup fails.
- The question ids live in `<env>/data/round-<n>.json`. POST `{"answers":{"<question-id>":"..."}}` to `http://127.0.0.1:<port>/g/<token>/round/<n>/answers` (the base is the URL minus `/round/<n>`). A 200 with `{"ok":true,"answers":N}` means every answer reached `pi.sendUserMessage`.
- Watch for your own marker string in the frames: the injected user message starts the next turn, which is the proof the loop continues.
- To keep a browser out of it, give the child a `PATH` whose first entry holds a no-op `xdg-open`; `lib/html.ts` spawns `xdg-open` by name, so `$BROWSER` is only reachable through xdg-utils itself.

## Traps that cost real cycles

- **Discoverable ≠ callable.** An extension tool registered without `loadMode` is treated as discoverable, and the model reaches it through the `xd://<tool>` device bridge (`tool_execution_start` shows `toolName: "write"`, `path: "xd://grill_finish"`). It works, but it is indirect. Set `loadMode: "essential"` on any tool the model must call reliably.
- **A hidden skill still registers a command.** With `disable-model-invocation: true` the skill is absent from the model's prompt list, so asking a fresh session to list skills proves nothing. Prove it with `{"type":"get_available_commands"}` and look for `skill:<name>`; `{"type":"get_state"}` and `data.dumpTools` lists the loaded tools.
- **A installed skill is still readable by URI.** `omp read skill://<name>` answering `Unknown skill` says nothing about discovery, but a fresh `-p` session that reads `skill://<name>` and reports the first line does prove the skill resolved.
- **`pi.sendUserMessage` works from an HTTP callback.** The extension factory closes over `pi`, and runtime actions are legal after load, so a bridge handler can inject answers into a session that is idle. Omit `deliverAs` to start a turn; it queues a steer while the session streams.
- **A thrown error inside an HTTP handler is contained** by the request try/catch and surfaces as HTTP 500 plus a JSON error body. A 500 on a route you think is wired is a missing import or a typo in a helper name, not a routing bug.
- **Unref the server.** `server.unref()` plus a `session_shutdown` close keeps a `-p` run from hanging on the listener.
- **An extension may import a sibling module.** Relative TS imports resolve, and a file under `extensions/lib/` is not loaded as an extension, because the scan loads only direct `*.ts` files and one-level subdirectories with an `index.ts`.

## What to assert for a page tool

Fetch the served URL and check the contract, not the prose: status code, one box per input, the buttons, the theme block, and the state endpoint. For a rendered artifact, read computed styles in a real browser (`agent_browser_*` MCP eval on `getComputedStyle`) rather than trusting the source markup; that catches a palette that parses but never applies. See `skill://verify-generated-html-artifact` and `skill://sandboxed-ui-verification`.
