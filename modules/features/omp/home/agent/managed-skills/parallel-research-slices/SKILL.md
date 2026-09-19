---
name: parallel-research-slices
description: "Split one oversized research question into parallel read-only subagent slices, brief them so they measure instead of rabbit-holing, then merge slices into a single cited answer artifact"
---

# Parallel research slices

Extends `skill://research` (which spawns **one** background agent) for a question too big for one
agent's 100K-token session, or with genuinely independent sub-questions. Worked case: a wayfinder
research ticket with four sub-questions (third-party asset availability, executing a bundled binary on
a modern mobile OS, cost/memory, partial-file/remote feasibility) resolved by three slices in one
session.

## 1. Decompose first, on independence

Cut by **evidence source**, not by wording of the question:

- one slice per primary source that must be read (a tool's source tree, a library's AAR/jar, a
  platform's sandbox rules);
- one slice per thing that must be **measured** (timings, byte counts, memory);
- never two slices that need the same file open.

State the sibling boundary in every brief: "sibling slices own X and Y, do NOT duplicate". Without
it, agents re-derive each other's facts (the cost slice here re-measured geometry another slice had
already verified, and had to label it as borrowed).

## 2. Brief each slice with a fixed contract

Every brief MUST carry:

- **The parent question and the decision it feeds**, one paragraph.
- **The slice's own numbered sub-questions**, each ending in a checkable statement.
- **Environment reality**: what this host cannot do, named explicitly — "no JDK, no Android SDK, no
  device, no display; do not attempt provisioning, builds or emulator runs" or "no GPU; the
  provisioning ticket is still open". Without this line, a slice asked "how long does X take" burns
  the session trying to build the thing.
- **Evidence classes** the answer must mark: `observed` (ran it, saw output), `source` (read at a
  named revision/file/symbol), `[INFERENCE]` (reasoned). Absolute numbers measured on the host must
  be labelled with the host, and the brief should ask which **ratios** survive the platform change.
- **Measure where measurement is cheap**: a synthetic input (generated clip, fixture, toy dataset) on
  the host beats documentation prose. Say so; the best slices here measured real numbers instead of
  quoting blogs.
- **A time box** and a size box: "do not download a large file", "broad web reading is fine".
- **The output contract** (below).
- **Repo access rules**: read-only, no `git`, no build tools, when siblings share one checkout.

## 3. Striped output contract

- Each agent writes its full report to its own path (`/tmp/<topic>/<slice>.md`), structured as
  `# title` / `## Question` / findings by sub-question / `## Sources` (URL + what it establishes) /
  `## Unknowns`.
- Each agent **returns only a digest** in its final message: one line per finding with a confidence
  (high/medium/low) and a citation key. This keeps the parent's context small.
- The parent merges: one answer file (decision-first, one screen of table + prose) with the slice
  files committed beside it as evidence. Do not paste slices into the answer; link them.

## 4. Parent-side duties

- **Verify a premise that looks wrong.** A ticket asserting a data shape ("the `storyboards` array in
  `--dump-single-json`") may be false; one slice's job is to confirm or refute it, and the answer must
  say so in a "Corrections" line. Never let a false premise shape the merge.
- **Reconcile contradictions before merging.** Two slices disagreed on an ffmpeg version bound
  (`-vsync 0` before 5.0). The slice that inspected the actual bundled binary wins; carry its
  conclusion, not the caveat that would make an implementer avoid a usable flag.
- **Read the slices, not only the digests**, when writing the answer: digests drop the qualifiers.
- **Hold the answer to the ticket's acceptance test**, sentence by sentence.
- Publish the artifact on the repo's research convention (a throwaway `research/<name>` branch) and
  leave the shared working checkout on the default branch.

## Traps observed

- Shared checkout + parallel agents: forbid `git` and writes inside the repo, or concurrent branch
  switches corrupt the index. Have each agent write to `/tmp` and let the parent commit once.
- `hub wait` may return an immediate "still running" snapshot instead of blocking; do not poll in a
  loop. Yield and let results auto-deliver.
- Agents can report completion before doing the work. Verify the artifact exists (issue created, file
  written, URL reachable) before believing a success report.
- A slice that cannot measure will estimate; demand the label, then say in the merged answer which
  numbers are host-bound and which ratios transfer.
