---
name: grill-me-html
description: "Grill the user through a web form instead of chat: each round is one HTML page with a box per question and a submit button. The submit sends the answers into the session, the loop continues until the frontier is empty, and a celebration page ends the run. Run this skill by name."
disable-model-invocation: true
---

# grill-me-html

The design-tree interview of `skill://grilling`, driven through a form. The user fills boxes in a browser instead of typing into the terminal, and each round arrives as one page.

## The loop

1. **Work the frontier.** The frontier is every decision whose prerequisites are settled. Facts are yours to find: dispatch a `scout` subagent for anything the filesystem, the repositories, or the network can answer. Never ask the user for a fact you can look up.

2. **One round, one call.** Call `grill_form` with every frontier question, most important first. The tool opens the page in the browser and returns its URL.

3. **Stop.** End the turn with one line that names the URL. Do not repeat the questions in chat. The submit injects the answers as the next user message, and your next turn starts with them.

4. **Recompute.** The answers reshape the tree: settled decisions push the frontier outward. Repeat from step 1.

5. **Finish.** When no question remains, call `grill_finish` with the settled decisions and the path of the finished report. It shows the celebration page and ends the loop.

6. **Record.** Write the interview to one Markdown file and render it with `render_html`. Report both paths.

## Writing the questions

Each question holds one decision, never two. A compound question yields an unusable answer.

- `title`: the decision, written as a question.
- `body`: the context and the options. A blank line starts a new paragraph. Add one "why this matters" line where the question could be misread.
- `recommendation`: your answer, in one sentence. The user can accept it as is.
- `choices`: two to four short options when the decision picks between named paths. Each becomes a button that fills the box.

Order the round most important first. A form is async, and one pass may be all you get.

Treat a partial answer and an "I don't know" as answers. Ask again only when the answer leaves the decision open. The form adds its own catch-all box, "Anything the round missed?"; read it and fold it into the tree.

## Rules

- Do not act on the tree until the user confirms a shared understanding.
- Do not invent an answer. An empty box is an open question, not a decision.
- One round per turn. Wait for the submit.
- Report the URL in one line, then end the turn. A wall of text defeats the form.

## Where the pages live

The pages and their data sit in the HTML environment folder for this session, printed by `grill_form` as `Environment: <dir>`:

- `data/round-<n>.json` the questions of one round
- `data/answers-<n>.json` the submitted answers
- `public/round-<n>.html`, `public/done.html` the served pages
- `flake.nix` a dev shell with Node and Bun, for a framework build (`nix develop <dir> -c bun run build`)
