---
name: dox-repo-with-gitignored-design-folder
description: "Bootstrap a new public project repo as a DOX project with a gitignored design folder holding the grilling record, ready to run wayfinder on. Use when a grilling session ends and the user asks to create the repo and stage the design material, or when a greenfield project needs its first commit plus planning material that must not be committed."
---

# DOX repo bootstrap with a gitignored design folder

Turns a finished design interview into a live repository: code-and-contract on the
remote, planning material local only.

## Order (matters)

1. `gh repo create <owner>/<name> --public --description "<one line>"` — create it
   **empty**: no `--add-readme`, no `--license`, so the first commit is yours.
2. Write the project root `AGENTS.md` **first**, before any other file: the DOX
   canonical template verbatim, with the Child DOX Index left as the
   "not yet indexed" placeholder. The first agent doing real work replaces it.
3. `LICENSE` — MIT unless the user picked otherwise. Copyright line uses the
   account's real name: `gh api user --jq '.login + " | " + (.name // "null")'`.
4. `.gitignore` — first entry is the design folder (`/.design/`), plus a modest
   set for the stack the milestones imply (Rust `target/`, Flutter `.dart_tool/`,
   `build/`, `.gradle/`, `.idea/`).
5. `.design/` — the planning material, never committed:
   - `design-record.md` the interview record (see below)
   - `design-record.html` the same, rendered with `render_html`
   - `grill/round-<n>.json` + `answers-<n>.json` (and the served `round-<n>.html`)
     copied from the grill session environment folder
   - `README.md` stating what each file is, the status (decided at epic level,
     not a build plan), and the wayfinder entry points: destination, decisions so
     far, fog, out of scope
6. Verify the ignore **before** the first push:
   `git check-ignore -v .design/design-record.md` must name the `.gitignore`
   line, and `jj status` / `git status --ignored` must show no `.design/` entry.
7. Commit and push the bootstrap **directly to the default branch**. The
   issue → branch → PR workflow applies only from the next change onward; do not
   open a PR for the bootstrap itself.
8. After the push, confirm the remote holds exactly the intended files:
   `gh api repos/<owner>/<name>/contents --jq '.[].path'`, plus
   `gh api repos/<owner>/<name> --jq '.private, .default_branch, .license.spdx_id'`.

## jj bootstrap (colocated, jj 0.45.1)

```bash
cd <project-dir>
jj git init --colocate
jj git remote add origin git@github.com:<owner>/<name>.git
jj describe -m "chore: bootstrap <name> with the DOX rail, MIT licence and ignore rules"
jj bookmark create main -r @
jj git push --bookmark main
```

Traps on 0.45.1:

- `jj git push --allow-new` **does not exist** (removed). New bookmarks push by
  default; do not reach for it.
- Pushing a bookmark makes `@` immutable and jj creates a fresh empty commit on
  top. That is expected, not a mistake.
- `.design/` never appears in `jj status` because jj honours `.gitignore`.

## Design record shape

Sections that earn their place:

- **What we are building** — one paragraph the reader can act on.
- **Facts established** — with sources, separated from decisions.
- **Decisions** — tables grouped by area, one row per settled answer, phrased as
  the decision rather than the question.
- **Decided without a question** — the calls the agent made, flagged as subject
  to veto, so the user can see them in one place.
- **Architecture as decided** — the component diagram and the one hot loop.
- **Scope of the first deliverable** — explicitly in / explicitly out.
- **Verification** — what proves each milestone.
- **Risks and open items**, including any claim carried from standard practice
  rather than verified in the session, marked **to verify**.
- **Appendix** — a question/answer table per round.

Do not assert what you did not verify. In this session two claims were softened
after the fact: a documented-but-unproved resolution mechanism, and a packaging
trick that is standard practice but untested — both became "to verify on the
first build" rather than settled fact.

## Wayfinder handoff

Wayfinder charts an effort too big for one session as a map of **decision**
tickets on the issue tracker; it plans and does not build. Point it at the record
by naming: the destination (the first deliverable's scope section), the decisions
already taken (do not re-open them as tickets; a changed decision is a new
ticket), the fog (the risk list and the milestone plan, which says what each
slice delivers but not how), and the out-of-scope list. GitHub Issues is the
best-supported tracker because native sub-issues and blocking render the frontier
without opening the map.
