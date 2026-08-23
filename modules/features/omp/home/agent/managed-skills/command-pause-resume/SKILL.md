---
name: command-pause-resume
description: "Pause the agent while a definite command is running; set a timer and poll indefinite commands; resume only when the command finishes."
---

# Command Pause/Resume Policy

When running external commands via the `bash` tool, follow this policy so the agent does not race ahead or abandon background work.

## Definite commands — pause and wait

A definite command exits on its own: builds, tests, lint, git operations, file copies, package installs, one-off scripts.

- Run it with `bash` synchronously (`async: false` or omitted).
- Do not call any other tool until the command returns.
- The agent is effectively paused while the command runs; this is the desired behavior.

## Indefinite commands — set a timer and poll

An indefinite command keeps running: dev servers, file watchers, `tail -f`, long sleeps, tunnels, anything that serves or loops.

- Start it with `bash { async: true }` and a reasonable `timeout`.
- If the command is auto-backgrounded by the runtime, capture the returned job ID.
- Poll the job with `job { "poll": [id] }` every 5 seconds until the job reports done or fails.
- Do not issue unrelated tools between polls; stay focused on the command.
- Once the job completes, resume normal work.

## Classifying ambiguous commands

Treat the whole command as indefinite if any of these appear:

- `serve`, `dev`, `watch`, `start`, `tail -f`, `sleep` with a duration over one minute, `nohup`, `&` backgrounding
- pipelines that end in an indefinite stage (`build && npm run dev`)
- interactive or server-like programs (e.g., `vite`, `next dev`, `webpack-dev-server`, `nodemon`)

When in doubt, run it as indefinite and poll.

## Cancellation and cleanup

If the command is no longer needed, stop it first with `job { "cancel": [id] }` before moving on.
