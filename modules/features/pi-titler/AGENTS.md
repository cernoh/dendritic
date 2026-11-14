# pi-titler — local title model

## Purpose

One llama.cpp router holding Qwen3-1.7B Q4_K_M, serving pi's session titles on
`127.0.0.1:8080`. A dendritic feature like any other: `import-tree` registers it
and NIXPC imports it, so the wrapper lands in that host's
`environment.systemPackages`. There is no nested flake — nothing runs from this
directory.

## Ownership

`default.nix` owns the whole deliverable: model pin, router preset, the
`pi-titler` wrapper, and a `homeManagerModules.pi-titler` systemd user
service that keeps the server resident on NIXPC (started on `default.target`).
The pi side is owned by `../pi-coding-agent/home/agent/` — this directory only
names the model id that `agents/title-generator.md` and `models.json` must
agree on.

## Local Contracts

- **The preset section name is the model id**, and three files must agree on it:
  `default.nix` (`modelId`), `models.json` (`models[].id`), and
  `agents/title-generator.md` (`model:` as `<provider>/<id>`). Today:
  `Qwen3-1.7B-Q4_K_M` served by provider `pi-titler`.
- **pi reaches it through a static `models.json` provider, never through pi's
  built-in `llama.cpp` provider.** `pi auth check --provider llama.cpp` answers
  `provider_not_found` in every configuration tried — bare `LLAMA_BASE_URL`,
  `-e builtin:llama.cpp`, and a stored credential in a pristine `HOME` — so
  `--list-models` omits it and `--model llama.cpp/…` fails. `models.json` has no
  discovery step to fail, and `/v1/chat/completions` is the route the smoke test
  proves. Re-test that check before reconsidering the built-in.
- **`reasoning = off` in the preset is load-bearing.** Qwen3's chat template
  defaults `enable_thinking` on; with it on the model spends all 512 tokens
  deliberating and returns empty content (`finish_reason: "length"`). Setting it
  server-side holds for clients that send no chat template kwargs, which is the
  case that broke first.
- **Router mode with `--models-preset`.** The preset is how the model gets
  `load-on-startup`, so it is resident before the first title. Loading on demand
  races the title request's own 15 s timeout. `--models-dir` would leave the
  model unlisted by any client that enumerates the router.
- **`cudaSupport` is a nixpkgs config flag**, set through
  `import nixpkgs { config = …; }` — not an argument on `llama-cpp`. It also needs
  `config.allowUnfree = true`, because the CUDA redistributables are unfree.
  CUDA is x86_64-only; aarch64 (ASAHI, Apple silicon) gets the CPU build. Verify
  offload with `nix run .#llama -- --list-devices`.
- **nixpkgs is the host's tree.** The module imports `inputs.nixpkgs` instead of
  declaring an input of its own, so there is no second `cudaPackages` and no
  second lockfile to bump; a nixpkgs bump is the top-level `flake.lock` and
  nothing else.
- **The GGUF is pinned by commit and hash.** Fetch with
  `nix store prefetch-file --hash-type sha256 <url-at-that-commit>`; never point
  at `resolve/main`.
- **The port is 8080** and `models.json` hardcodes it, so a different
  `PI_TITLER_PORT` also needs that file edited.
- **Losing the server degrades, it does not break.** With no server the model is
  unavailable and the title extension falls back to the session's own model.
- **The agent prompt's closing example is functional, and must be its only
  example.** Without `Example output format: Fix auth redirect loop in dendritic`
  the model answers in kebab-case, and an explicit "no hyphens" rule does not
  correct it — only a concrete example does. With a second example of the same
  shape (a bullet's inline parenthetical), the model echoes the example verbatim
  instead of titling the session, deterministically through pi even when raw
  `curl` to the same server still produces titles.

## Work Guidance

- `nix fmt` (nixfmt RFC style) formats this file like any other module.
- Run it from the flake root: `nix run .#pi-titler`, or the installed `pi-titler`
  binary on NIXPC. No `git add` step — `import-tree` already registered the
  module in the top-level tree.

## Verification

```sh
nix-instantiate --parse modules/features/pi-titler/default.nix
nix eval .#packages.x86_64-linux.pi-titler.name --impure   # "pi-titler"
nix run .#pi-titler -- --list-devices         # RTX 3050 named when CUDA is on
curl -s http://127.0.0.1:8080/models | head -c 200   # status loaded, source preset
pi --list-models | grep titler                 # pi-titler Qwen3-1.7B-Q4_K_M
```

A title request sent **without** `chat_template_kwargs` must return text, not an
empty string — that is the regression the `reasoning = off` preset key guards.

## Child DOX Index

None.
