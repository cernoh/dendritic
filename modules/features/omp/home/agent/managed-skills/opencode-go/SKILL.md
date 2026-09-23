---
name: opencode-go
description: "ARCHIVED: OpenCode Go (opencode-go) models in omp. Roles moved to commandcode GOAT models 2026-09-23; kept for endpoint/registry/cap history only."
---
Trawled from <https://opencode.ai/docs/go/> plus local verification on NIXPC, 2026-09-16.
Model list, caps, and prices re-checked 2026-09-16 against <https://opencode.ai/docs/go/#usage-limits>
(the canonical pricing and cap table), the live account registry, and
<https://opencode.ai/data/> (real usage ranking, updated 2026-09-16).

Refreshed 2026-09-18 against the same three sources: 37 live registry ids, 28 of
them on the docs endpoints table. The advisor role moved to
`opencode-go/deepseek-v4.1-flash` on the same day.

## What OpenCode Go is

- $10/month subscription for open coding models. Optional. Key from the OpenCode Zen console at <https://opencode.ai/auth>.
- Usage is capped per model as a monthly dollar amount. Each cap splits into: 5-hour = 20%, weekly = 50%, monthly = 100%.
- Enable **Use balance** in the console to fall back to Zen credit after a cap instead of blocking requests.
- Track usage at <https://opencode.ai/auth>.

## Model ids (session with the provider)

Base URL: `https://opencode.ai/zen/go/v1`. Selector format in client configs: `opencode-go/<model-id>`.

| Model | Model id | Endpoint |
| --- | --- | --- |
| Grok 4.6 | `grok-4.6` | `/responses` |
| GPT 5.6 Luna | `gpt-5.6-luna` | `/responses` |
| Muse Spark 1.3 Contributor | `muse-spark-1.3-contributor` | `/responses` |
| Muse Spark 1.2 Contributor | `muse-spark-1.2-contributor` | `/responses` |
| GLM-5.3-Flash | `glm-5.3-flash` | `/chat/completions` |
| GLM-5.3 | `glm-5.3` | `/chat/completions` |
| GLM-5.2 | `glm-5.2` | `/chat/completions` |
| GLM-5.1 | `glm-5.1` | `/chat/completions` |
| Kimi K3 | `kimi-k3` | `/chat/completions` |
| Kimi K2.7 Code | `kimi-k2.7-code` | `/chat/completions` |
| Kimi K2.6 | `kimi-k2.6` | `/chat/completions` |
| LongCat-2.0 | `longcat-2.0` | `/chat/completions` |
| DeepSeek V4.1 Flash | `deepseek-v4.1-flash` | `/chat/completions` |
| DeepSeek V4 Pro | `deepseek-v4-pro` | `/chat/completions` |
| DeepSeek V4 Flash | `deepseek-v4-flash` | `/chat/completions` |
| DeepSeek V4 Flash Vision Exp | `deepseek-v4-flash-vision-exp` | `/chat/completions` |
| MiMo-V2.5 | `mimo-v2.5` | `/chat/completions` |
| MiMo-V2.5-Pro | `mimo-v2.5-pro` | `/chat/completions` |
| Hy4 preview | `hy4-preview` | `/chat/completions` |
| Hy3 | `hy3` | `/chat/completions` |
| MiniMax M3 | `minimax-m3` | `/messages` |
| MiniMax M2.7 | `minimax-m2.7` | `/messages` |
| MiniMax M2.5 | `minimax-m2.5` | `/messages` |
| Qwen3.8 Max | `qwen3.8-max` | `/messages` |
| Qwen3.8 Flash | `qwen3.8-flash` | `/messages` |
| Qwen3.7 Max | `qwen3.7-max` | `/messages` |
| Qwen3.7 Plus | `qwen3.7-plus` | `/messages` |
| Qwen3.6 Plus | `qwen3.6-plus` | `/messages` |

Model list metadata: `GET https://opencode.ai/zen/go/v1/models`.

The account registry serves 37 ids, and the docs endpoints table covers 28 of
them. These 9 ids have no docs row:

- Legacy ids: `glm-5`, `grok-4.5`, `kimi-k2.5`, `qwen3.5-plus`.
- Extra ids: `mimo-v2-omni`, `mimo-v2-pro`, `hy3-preview`.
- Null-metadata ids: `deepseek-flash`, `omen-alpha`. The registry reports no context window, no output limit, and a zero price for both. Do not read the zero as a subsidy: `hy3-preview` shows the same zeros, while its documented twin `hy3` costs $0.14/$0.58. The zero is absent metadata.

`omen-alpha` is not a stub in the wiring sense. Tested 2026-09-18: it answered a
one-shot prompt, and it ran a full advisor review pass with tool calls and
correct reasoning. The registry lists no price for it, and omp derives its local
cost figure from that same metadata, so a local `cost.total` of zero proves
nothing. The Zen console is the only authority on metering. The id carries no
docs row and no declared context window, so keep it off a standing role. Use it
through an explicit `--model opencode-go/omen-alpha` pick for non-private,
throwaway work.

Preview and promotional ids leave without notice. `ox-alpha-free` sat in the
registry on 2026-09-16 and was gone on 2026-09-18, and `union-alpha` lost its
docs row over the same two days. Re-check before you pin a role to a preview id.

Monthly caps and prices change often. Treat the table below as a starting point, and re-check the docs page or the live catalog before you commit to a role model.

Monthly caps worth knowing before choosing a role model:

```
DeepSeek V4.1 Flash      $60*     GLM-5.3-Flash        $60
DeepSeek V4 Flash        $30      GLM-5.2 / GLM-5.1    $60 each
DeepSeek V4 Pro          $15      GLM-5.3              $15
DeepSeek V4 Flash Vis.   $15      Kimi K2.7 Code / 2.6 $60 each
GPT 5.6 Luna             $15      Kimi K3              $15
Muse Spark 1.3 / 1.2 C.  $60      MiMo V2.5            $60
Qwen3.8 Flash            $30      MiMo V2.5 Pro        $15
Qwen3.7 Max              $30      MiniMax M3/M2.7/M2.5 $60 each
Qwen3.6 / Qwen3.7 Plus   $60      LongCat-2.0          $60
Hy4 preview              $30      Hy3                  $60
Grok 4.6                 $15
```

\* DeepSeek V4.1 Flash runs a 4x cap promotion that ends 2026-09-20, then
returns to $15. Re-check the table before you lean on that cap.

DeepSeek prices double at peak hours: 01:00-04:00 and 06:00-10:00 UTC, Monday through Friday. All other hours and all weekends are off-peak. Run large jobs off-peak.

Privacy: DeepSeek traffic is zero-data-retention, and the agreement renews monthly, valid through 2026-09-30. Muse Spark Contributor permits Meta to train on your prompts. Grok 4.6 and GPT 5.6 Luna hold abuse-monitoring logs for 30 days. Every other model holds data for 0 days. Read the page before you use Muse Spark on private code.

Client requirements from the page: send ordinary coding-agent traffic, identify with your own user agent, and send a stable per-conversation id in the `x-opencode-session` header for routing and prompt caching.

## omp provider wiring

- Provider id `opencode-go` (name "OpenCode Go"). Env var `OPENCODE_API_KEY`. Bearer auth. Base URL `https://opencode.ai/zen/go/v1`.
- The provider descriptor sets `dynamicModelsAuthoritative: true`. The account's live `/models` list wins, so new model ids appear without a new omp binary.
- Bundled provider default model is `kimi-k2.7-code`. `modelRoles` overrides it.
- The live account list is larger than the docs page. Expect legacy and preview ids as well.
- Inspect with `omp models opencode-go`, `omp models --json opencode-go`, or `omp models find <substring>`. Force a catalog refetch with `omp models refresh`.
- Discovery cache lives in `~/.omp/agent/models.db`, table `model_cache`, rows keyed `opencode-go:models-v3:<account-hash>`, model list in the `models` JSON column.

## Model id trap: display name is not the id

The UI name and the selector differ. Never invent a slug from the display name.

| Display name | Correct selector |
| --- | --- |
| DeepSeek V4.1 Flash | `opencode-go/deepseek-v4.1-flash` |
| DeepSeek V4 Flash | `opencode-go/deepseek-v4-flash` |
| DeepSeek V4 Pro | `opencode-go/deepseek-v4-pro` |
| DeepSeek V4 Flash Vision Exp | `opencode-go/deepseek-v4-flash-vision-exp` |

The bare `deepseek-flash` id is a null-metadata stub (no context, pricing, or thinking levels in the live registry). Never use it.

Copy the id from the registry, never from prose. Two ways:

```bash
omp models --json opencode-go
```

```sql
SELECT value->>'id', value->>'name'
FROM model_cache, json_each(models)
WHERE provider_id LIKE 'opencode-go%' AND value->>'name' LIKE '%4.1%';
```

## Usage ranking: <https://opencode.ai/data/>

The OpenCode team publishes real token volume per model. Treat it as a popularity proxy for quality — the most used models are usually the best ones, but a model can rank low from price alone.

Top models, 2026-09-18 (tokens, weekly retention):

```
1  deepseek-v4.1-flash          46T    new
2  muse-spark-1.3-contributor   34T    87.4%
3  deepseek-v4-flash            17T    68.3%
4  mimo-v2.5                    7.3T   72.9%
5  glm-5.3-flash                3.2T   68.8%
6  muse-spark-1.2-contributor   3.0T   81.5%
7  nemotron-3-ultra             2.4T   no Go entry
8  deepseek-v4-flash-vision-exp 966B   69.6%
9  deepseek-v4-pro              649B
10 ling-3.0-flash-fin           538B   no Go entry
11 gpt-5.6-luna                 518B
12 union-alpha                  470B   no Go entry
14 qwen3.8-flash                302B   72.3%
15 minimax-m3                   266B
```

Author token share: DeepSeek 59.1%, Meta 30.9%, Xiaomi 4.8%, NVIDIA 3.0%.

The ranking spans every provider, so a top row can be absent from Go.
`nemotron-3-ultra`, `nemotron-3.5-lightning`, `ling-3.0-flash-fin`, and
`union-alpha` have no Go id.

## Role picks (ARCHIVED 2026-09-23)

Roles now use `commandcode` GOAT models (see `modules/features/omp/default.nix`).
The table below is the last opencode-go shape, kept for history.

```text
role      model                        in / out    ctx / max-out  vision  cap/mo
default   deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
task      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
plan      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
slow      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
smol      deepseek-v4-flash            0.15/0.60   1.0M / 384K    no      $30
commit    deepseek-v4-flash            0.15/0.60   1.0M / 384K    no      $30
vision    deepseek-v4-flash-vision-exp 0.15/0.60   1.0M / 384K    yes     $15
advisor   deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
```

Prices are off-peak, from the live registry. Caps are from the docs table.

Why this shape:

- DeepSeek V4.1 Flash drives every heavy role. It is the most used model on the 2026-09-18 ranking, the cheapest capable one, and it carries vision.
- `advisor` shares that model. Muse Spark 1.3 Contributor left the role on 2026-09-18, because it repeats blocker-severity notes with no new signal.
- The cheap roles split across two extra DeepSeek caps (`deepseek-v4-flash` at $30, `vision-exp` at $15), so one cap wall does not stop everything.
- Muse Spark Contributor permits Meta to train on prompts. Keep it out of the `default` chain. It serves only the `issue-scribe` agent, which receives a brief and repository reads instead of the session transcript.
- Six roles keep vision support, so paste-a-screenshot flows work without a manual model switch.
- Leave `modelRoles.tiny` unset while `providers.tinyModel` runs a local model. The local model costs nothing.

## Fallback chains

`retry.modelFallback` is the enable switch, and it defaults to `true`. `retry.fallbackChains` maps a role, an exact `provider/model-id`, or a `provider/*` wildcard to an ordered selector list. A `default` chain covers every role without its own entry.

Pick hops that own separate monthly caps, so a cap wall or an outage fails over instead of blocking the turn.

```bash
omp config set retry.fallbackChains '{"default":["opencode-go/deepseek-v4-flash","opencode-go/glm-5.3-flash"],"slow":["opencode-go/deepseek-v4-flash","opencode-go/deepseek-v4-pro"]}'
omp config get retry.fallbackChains
omp config get retry.fallbackRevertPolicy
```

`fallbackRevertPolicy` defaults to `cooldown-expiry`, which returns to the primary model once the suppression window ends.

Check every selector against the live registry, and check that the registry kept every chain entry. It drops unknown models.

```bash
omp models --json opencode-go > /tmp/m.json
omp config get retry.fallbackChains --json
```

## Write it into the dendritic flake

1. Edit `modules/features/omp/default.nix`, keys `programs.omp.settings.modelRoles` and `programs.omp.settings.retry.fallbackChains`.
2. Apply to the running install without a rebuild. Records take one JSON value, and dotted record paths fail with "Unknown setting".

```bash
omp config set modelRoles '{"default":"opencode-go/deepseek-v4.1-flash","task":"opencode-go/deepseek-v4.1-flash","plan":"opencode-go/deepseek-v4.1-flash","slow":"opencode-go/deepseek-v4.1-flash","smol":"opencode-go/deepseek-v4-flash","commit":"opencode-go/deepseek-v4-flash","vision":"opencode-go/deepseek-v4-flash-vision-exp","advisor":"opencode-go/deepseek-v4.1-flash"}'
```

3. Never commit `modules/features/omp/home/agent/config.yml`. Home Manager regenerates it wholesale from the settings through `home.activation.ompConfig`, and the live copy carries drift from `/settings` and migrations. Commit `default.nix` only.
4. A role change applies to new sessions. The running session keeps its model.

Valid roles: `default`, `task`, `plan`, `slow`, `advisor`, `smol`, `vision`, `tiny`, `commit`.

## Verification

```bash
nix-instantiate --parse modules/features/omp/default.nix
nix eval --impure --raw '.#nixosConfigurations.NIXPC.config.home-manager.users.davr.home.activation.ompConfig.data'
nix eval --impure --raw '.#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath'
omp config get modelRoles
omp config get retry.fallbackChains
omp models find deepseek-v4.1-flash
```

The activation-script eval prints the generated YAML, so it proves the rendered roles and chains in one step. For format and PR mechanics, use `dendritic-feature-change-verification` and `dendritic-stacked-prs-and-worktrees`. `Evaluate NIXPC` and `Evaluate ASAHI` in Nix CI are green since #173, so a red eval is your change.
