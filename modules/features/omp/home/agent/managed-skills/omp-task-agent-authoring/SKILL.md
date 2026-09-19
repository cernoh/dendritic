---
name: omp-task-agent-authoring
description: "Author, wire, and prove an omp specialist task agent (custom subagent) in the dendritic flake: frontmatter traps (camelCase-only autoloadSkills), the dispatch-probe discovery check, why PI_CODING_AGENT_DIR cannot verify, making delegation mandatory via RULES.md, and model-choice rules (shared caps, zero-price means missing metadata). Use when adding or debugging a subagent in ~/.omp/agent/agents/ or making the main agent delegate a class of work."
---

# Authoring and proving an omp task agent

Verified 2026-09-18 on `cernoh/dendritic` while adding the `issue-scribe`
subagent (issues #230/#232, PRs #231/#233).

## Where a definition lives

- User scope: `~/.omp/agent/agents/<name>.md` (here the out-of-store target is
  `modules/features/omp/home/agent/agents/`).
- Project scope: `<cwd>/.omp/agents/<name>.md`. Project wins over user; both win
  over bundled agents. Name matching is case-sensitive, first wins.
- `home/.gitignore` ignores `agent/*`, so a tracked agent dir needs a re-include:
  `!agent/agents/` **and** `!agent/agents/**` (a re-include cannot resurrect
  files inside an ignored directory).

## Frontmatter

Accepted keys include `name`, `description`, `model` (one selector, CSV, or a
list), `tools`, `spawns`, `blocking`, `thinking-level`, `read-summarize`,
`prewalk`, `advisor`, `autoloadSkills`. Kebab-case normalizes to camelCase for
most keys (`read-summarize` ≡ `readSummarize`, both verified).

**`autoloadSkills` is camelCase only.** `autoload-skills` is accepted without an
error and injects nothing. Proved with two probe agents in one dispatch: the
camelCase agent's first prompt contained `# ste-writing`, the kebab-case agent's
did not.

An unknown key rejects the file (`unexpected frontmatter field`), and a rejected
file is skipped with a warning only. Never trust a written definition: prove
discovery.

- Leaf agent: list explicit `tools` and omit `spawns`. Without `spawns` the
  `task` tool is not auto-added, so the specialist cannot spawn. `yield` is
  auto-added.
- `blocking: true` makes the parent wait even with async task execution on. Use
  it when the parent needs the child's output (an issue number, a URL).

## Prove discovery and dispatch

One call lists every discoverable agent, including your new one:

```bash
omp -p --no-session --no-title --auto-approve \
  'Call the task tool once with agent "zzz-probe" and task "x". Then print the exact error text verbatim.'
# → Task #1 failed preflight: Unknown agent "zzz-probe". Available: …
```

Then dispatch the real agent for real work and check the artifact it produced
(the issue, the file, the PR). A green-looking definition proves nothing.

**Do not verify with `PI_CODING_AGENT_DIR`.** Pointing it at a worktree's agent
dir relocates the whole profile, which carries no credentials:

```text
No models available. Use /login or set an API key environment variable.
```

## Live vs worktree

The out-of-store `~/.omp` symlink points at the **main checkout**, so a file in
a `.worktrees/<name>` checkout is not live. To test before merge, copy the
definition into the live agent dir — `agent/*` is gitignored there, so the copy
leaves no repo dirt and `git status` stays clean. Confirm the copy still matches
the committed file before you call the test valid:

```bash
git show <branch>:modules/features/omp/home/agent/agents/<name>.md | diff - ~/.omp/agent/agents/<name>.md
```

For an experiment that must not touch the saved config, pass a process-scoped
overlay: `omp --config /tmp/overlay.yml -p …` with `modelRoles` / `advisor`
keys. Overlay files are strict: missing, invalid, or non-mapping files fail hard.

## Make delegation mandatory

An agent definition does not make the main agent use it. `home/agent/RULES.md`
is the global sticky rule file loaded into every session; add a numbered rule
that names the agent, the trigger ("every issue title, body, sub-issue, and
comment"), the dispatch call, and an escape hatch for when the agent is
unreachable. Keep it generic, because it applies to every repository.

## Model choice for the agent

- A concrete selector in `model:` is fine when the user names the model. Use a
  role alias (`model: "@issues"` plus `modelRoles.issues`) when the model may
  change, so a retarget needs no edit to the definition.
- **A shared model is a shared monthly cap.** opencode-go meters per model, so
  putting a chatty role (an advisor reviews every transcript update) on the same
  model as `default`/`task`/`plan`/`slow` makes it compete for one pool. Keep
  cap isolation when the chain comments claim it.
- **A zero price in the registry is missing metadata, not a subsidy.**
  `deepseek-flash`, `hy3-preview`, and `omen-alpha` all report
  `cost 0/0/0/0` with `contextWindow: null`, while their documented twins cost
  real money. Never call such a model free; the provider console is the only
  price authority. A model with no declared context window is also a poor fit
  for a role whose context maintenance needs a number.
- The advisor transcript's `usage.cost.total: 0` is computed from the same
  metadata, so it is circular evidence for a price claim.

## Prose that must pass a repository STE gate

When the agent writes issue or PR text, match the CI input exactly: the workflow
lints `printf '%s\n\n%s\n' title body`.

```bash
printf '%s\n\n%s\n' "$TITLE" "$BODY" | nix shell nixpkgs#python3 --command python3 .github/scripts/ste-lint.py
```

- The linter reads stdin **only** when no file argument is passed; with a path it
  prints a summary line and hides the rules that fired.
- `python3` is absent on this host, so run it through `nix shell nixpkgs#python3`.
- Blank-line-separate every list item. A tight bullet block counts as ONE
  paragraph with N sentences and fires `long_paragraph(>6s)` — that single
  violation was the only thing between a 238-word PR body and total 0.
- Drive `total` to 0 before creating or editing the issue or PR. The workflow
  re-runs on edits and rejects a nonzero total.
