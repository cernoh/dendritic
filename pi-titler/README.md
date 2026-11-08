# pi-titler

A local llama.cpp server holding one small model — Qwen3-1.7B Q4_K_M — used only
to name pi sessions. It replaces the API call the `title-generator` agent makes
every few turns with a GPU-resident 1 GB model, so tab titles cost nothing and
survive being offline.

This is a **standalone flake** inside the dendritic checkout: it is not part of
`modules/` and importing it changes nothing about the host build.

## Run it

```sh
nix run ./pi-titler            # 127.0.0.1:8080
PI_TITLER_PORT=8090 nix run ./pi-titler
nix run ./pi-titler -- --verbose   # extra args go to llama-server
```

The flake source copy only carries tracked files, so `git add pi-titler` before
the first run.

`nix run .#llama -- --list-devices` names the offload device; on NIXPC it must
list the RTX 3050, which proves the build picked up CUDA. Measured on that card:
271 prompt tokens in 82 ms, 8 title tokens in 62 ms — a title is ~150 ms.

## Wire pi to it

Nothing to configure by hand. `~/.pi/agent/models.json` — tracked in this repo at
`modules/features/pi-coding-agent/home/agent/models.json` — declares the endpoint
as an ordinary OpenAI-compatible provider:

```json
"pi-titler": {
  "baseUrl": "http://127.0.0.1:8080/v1",
  "api": "openai-completions",
  "apiKey": "pi-titler",
  "models": [{ "id": "Qwen3-1.7B-Q4_K_M", "contextWindow": 16384, "maxTokens": 512 }]
}
```

`agents/title-generator.md` names `pi-titler/Qwen3-1.7B-Q4_K_M`. So: start the
server, restart pi, done. Confirm with `pi --list-models | grep titler`.

### Why not the built-in llama.cpp provider

pi ships a `llama.cpp` built-in that discovers a router and lists its models. It
is unusable here: `pi auth check --provider llama.cpp` reports
`provider_not_found` in every configuration tried — plain env, `-e
builtin:llama.cpp`, and a stored credential in a pristine `HOME` — so
`--list-models` never shows it and `--model llama.cpp/…` fails with "Model not
found". A static `models.json` provider has no discovery step to fail, and the
`/v1/chat/completions` route it uses is the one proven by the smoke test below.

If the server is not running, the model is simply unavailable; the title
extension then falls back to the session's own model, so nobody loses titles —
they are just paid for again.

## As a user service

```ini
# ~/.config/systemd/user/pi-titler.service
[Unit]
Description=Local title model for pi sessions
After=graphical-session.target

[Service]
ExecStart=%h/.config/dendritic/pi-titler/result/bin/pi-titler
Restart=on-failure

[Install]
WantedBy=default.target
```

Build that `result` symlink once with `nix build ./pi-titler -o pi-titler/result`
before enabling the unit. `ExecStart` cannot be `nix run`: a systemd unit has no
`nix` on its PATH.

## Why these choices

- **`reasoning = off` in the preset is load-bearing.** Qwen3's chat template
  defaults `enable_thinking` to on. With it on, the model spends the entire
  512-token budget deliberating and returns an **empty** content string
  (`finish_reason: "length"`, measured). Setting it server-side holds for any
  client, including one that sends no chat template kwargs.
- **Router mode plus a preset.** A preset is also how the model gets
  `load-on-startup`, so it is resident before the first title arrives. Loading on
  demand races the title job's own 15 s timeout.
- **`ctx-size` 16384.** Titles stop improving well before that; the number is
  there so a long session is not silently truncated. It costs ~1 GB of KV cache,
  which the 8 GB card does not notice.
- **`--no-webui`.** The router's browser UI has an `--ui-mcp-proxy` flag beside
  it in the same table; a title server should not be reachable from a page by
  accident.
- **nixpkgs pinned to the host's revision.** A second tree means a second
  `cudaPackages` and the whole CUDA stack re-downloaded.

## Prompt note

The agent prompt ends with `Example output format: Fix auth redirect loop in
dendritic`. That line is not decoration: without it the 1.7B model answers in
kebab-case (`pi-titler-flake-session`), and an explicit "never use hyphens" rule
does not fix it — only a concrete example does.

It must also be the prompt's **only** example. Two examples of the same shape —
the one in a bullet (`not generic ("Fix auth bug in dendritic", …)`) plus the
closing line — make the model parrot the example verbatim instead of titling the
session, deterministically through pi even though raw `curl` still looked fine.
Measured through pi, 2 samples per session type:

| prompt shape | result |
|---|---|
| inline example + closing example | 4/4 echoed `Fix auth redirect loop in dendritic` |
| inline example + a *different* closing example | closing example echoed 2/2 on the flake session |
| closing example only | 4/4 real titles, no echo |

## Verify

```sh
nix build ./pi-titler -o pi-titler/result && ./pi-titler/result/bin/pi-titler &
curl -s http://127.0.0.1:8080/models | head -c 400   # preset listed, status loaded
pi --list-models | grep titler                       # pi-titler Qwen3-1.7B-Q4_K_M
pi --no-session --no-tools --model pi-titler/Qwen3-1.7B-Q4_K_M -p 'Say OK'
```

A real title, end to end:

```sh
curl -s http://127.0.0.1:8080/v1/chat/completions -H 'content-type: application/json' \
  -d '{"model":"Qwen3-1.7B-Q4_K_M","max_tokens":512,"messages":[
       {"role":"system","content":"Name this coding session in under 80 characters. Output only the title. Example output format: Fix auth redirect loop in dendritic"},
       {"role":"user","content":"Session: wrote a nix flake serving Qwen3-1.7B through llama.cpp with CUDA for local title generation."}]}'
```
