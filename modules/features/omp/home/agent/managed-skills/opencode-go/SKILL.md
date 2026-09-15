---
name: opencode-go
description: "Work with OpenCode Go (opencode-go) models in omp: the doc fact sheet (models, ids, endpoints, plan limits, DeepSeek peak hours, privacy), omp provider wiring and live discovery, model id vs display name traps, the cheap per-role model picks, fallback chains, and how to write it all into the dendritic flake."
---

Trawled from <https://opencode.ai/docs/go/> plus local verification on NIXPC, 2026-09-10.
Role picks and prices re-checked 2026-09-15 against <https://opencode.ai/docs/go/#usage-limits>
(the canonical pricing and cap table) and <https://opencode.ai/data/> (real usage ranking).

## What OpenCode Go is

- $10/month subscription for open coding models. Optional. Key from the OpenCode Zen console at <https://opencode.ai/auth>.
- Usage is capped per model as a monthly dollar amount. Each cap splits into: 5-hour = 20%, weekly = 50%, monthly = 100%.
- Enable **Use balance** in the console to fall back to Zen credit after a cap instead of blocking requests.
- Track usage at <https://opencode.ai/auth>.

## Model ids (session with the provider)

Base URL: `https://opencode.ai/zen/go/v1`. Selector format in client configs: `opencode-go/<model-id>`.

| Endpoint suffix | Models |
| --- | --- |
| `/responses` | Grok 4.6, GPT 5.6 Luna, Muse Spark 1.3 and 1.2 Contributor |
| `/chat/completions` | GLM-5.1/5.2/5.3/5.3-Flash, Kimi K3/K2.7 Code/K2.6, DeepSeek V4.1 Flash, DeepSeek V4 Pro, DeepSeek V4 Flash, DeepSeek V4 Flash Vision Exp, MiMo-V2.5, MiMo-V2.5-Pro, LongCat-2.0, Hy3, Hy4 preview |
| `/messages` | MiniMax M3/M2.7/M2.5, Qwen3.6 Plus, Qwen3.7 Plus/Max, Qwen3.8 Flash/Max |

Model list metadata: `GET https://opencode.ai/zen/go/v1/models`.

Monthly caps and prices change often. Treat the table below as a starting point, and re-check the docs page or the live catalog before you commit to a role model.

Monthly caps worth knowing before choosing a role model:

```
DeepSeek V4.1 Flash      $60*     GLM-5.3-Flash        $60
DeepSeek V4 Flash        $30      GLM-5.3              $15
DeepSeek V4 Pro          $15      Kimi K3              $15
DeepSeek V4 Flash Vis.   $15      Kimi K2.7 Code       $60
Qwen3.8 Flash            $30      MiMo V2.5 / Pro      $60 / $15
Qwen3.8 Max              $15      MiniMax M3           $60
GPT 5.6 Luna             $15      Muse Spark 1.3 C.    $60
```

\* DeepSeek V4.1 Flash runs a 4x cap promotion that ends 2026-09-20, then
returns to $15. Re-check the table before you lean on that cap.

DeepSeek prices double at peak hours: 01:00-04:00 and 06:00-10:00 UTC, Monday through Friday. All other hours and all weekends are off-peak. Run large jobs off-peak.

Privacy: DeepSeek traffic is zero-data-retention, and the agreement renews monthly, valid through 2026-09-30. Muse Spark Contributor permits Meta to train on your prompts. Read the page before using either on private code.

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

Top models, 2026-09-15 (tokens, weekly retention):

```
1  muse-spark-1.3-contributor   36T   87%
2  deepseek-v4.1-flash          32T   pending
3  deepseek-v4-flash            20T   68%
4  mimo-v2.5                    8.9T  73%
6  glm-5.3-flash                3.6T  69%
8  deepseek-v4-flash-vision-exp 1.0T  70%
9  deepseek-v4-pro              708B  62%
```

Author token share: DeepSeek 56.0%, Meta 28.9%, Xiaomi 7.4%, Zhipu 3.5%, NVIDIA 2.0%.

## Role picks: cheapest capable model per role

```text
role      model                        in / out    ctx / max-out  vision  cap/mo
default   deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
task      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
plan      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
slow      deepseek-v4.1-flash          0.15/0.60   1.0M / 384K    yes     $60*
smol      deepseek-v4-flash            0.15/0.60   1.0M / 384K    no      $30
commit    deepseek-v4-flash            0.15/0.60   1.0M / 384K    no      $30
vision    deepseek-v4-flash-vision-exp 0.15/0.60   1.0M / 384K    yes     $15
advisor   muse-spark-1.3-contributor   0.10/0.20   1.0M / 131K    yes     $60
```

Prices are off-peak, from the live registry. Caps are from the docs table.

Why this shape:

- DeepSeek V4.1 Flash drives every heavy role. It is the most used DeepSeek model, the cheapest capable one, and it carries vision.
- The cheap roles split across two extra DeepSeek caps (`deepseek-v4-flash` at $30, `vision-exp` at $15), so one cap wall does not stop everything.
- `advisor` uses Muse Spark 1.3 Contributor ($0.10/$0.20). It is the most used model on the ranking, and it gives a different family for a second opinion.
- Muse Spark Contributor permits Meta to train on prompts, so keep it on `advisor` only and out of the `default` chain.
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
omp config set modelRoles '{"default":"opencode-go/deepseek-v4.1-flash","task":"opencode-go/deepseek-v4.1-flash","plan":"opencode-go/deepseek-v4.1-flash","slow":"opencode-go/deepseek-v4.1-flash","smol":"opencode-go/deepseek-v4-flash","commit":"opencode-go/deepseek-v4-flash","vision":"opencode-go/deepseek-v4-flash-vision-exp","advisor":"opencode-go/muse-spark-1.3-contributor"}'
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
