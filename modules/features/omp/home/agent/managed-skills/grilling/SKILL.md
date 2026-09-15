---
name: grilling
description: "Grill the user relentlessly about a plan, a decision, or an idea. Use when the user wants to stress-test their thinking, or uses a 'grill' trigger phrase. The session ends with a rich HTML record of the design tree."
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you have not heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, the network), dispatch a `scout` subagent with the `task` tool to find it. Do not ask the user for anything you can look up yourself. Do not block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the subagent to report. Ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

## Keep the record

Write the interview to one Markdown file, either as you go or in one pass at the end. Keep this shape:

```
# <topic>

## Round 1

<the round text exactly as posted>

## Round 2

...

## Settled decisions

- **<decision title>:** <outcome, plus the reason the user gave>
```

Write it to `/tmp/grilling-<topic-slug>.md` unless the user names another path. The record is the input for the next section, and it outlives the session.

## Render the record as HTML

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on the tree until the user confirms you have reached a shared understanding.

Then call the `render_html` tool with `path` set to the record file. The tool writes a self-contained HTML page and returns its path. Report that path to the user. Pass `open: true` when the user wants to see the page now.

The tool pairs each `❓` question with the `➡️` recommendation below it, and gives every question its own card. Keep the round format above so the page stays readable.

When the user wants a page with its own layout, such as a comparison, a diagram, or a slide deck, read `skill://show-html` and write the page yourself. If the `render_html` tool is absent, do the same.
