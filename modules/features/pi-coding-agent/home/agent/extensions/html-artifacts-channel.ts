// Modular HTML-artifact channel.
// Delete THIS FILE to remove the behaviour completely — nothing else in pi
// depends on it. The html-artifacts skill stays usable by hand either way.
import { homedir } from "node:os";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SKILL_DIR = path.join(homedir(), ".agents", "skills", "html-artifacts");

const CHANNEL = `## Primary channel: HTML artifacts

Anything the user must **read and compare** ships as ONE self-contained HTML
file in \`<repo>/artifacts/<kebab-slug>.html\`: specs, plans, explorations,
reviews, explainers, status reports, and every interactive form. Chat prose
accompanies the page; it never replaces it. Load the \`html-artifacts\` skill
before writing one — it owns the build procedure, the exploration-card contract
and the theme.

- Skill: ${SKILL_DIR}/SKILL.md · theme (canonical, the only place a hex may
  appear): ${SKILL_DIR}/theme.css · start from \`template.html\`
  (exploration/plan) or \`frontier.html\` (a form).
- Ship the exact prompt that produced the artifact in \`.prompt-box\`.
- Render it (\`agent_browser\` open + screenshot), look at the screenshot, then
  hand it over: give the file path and open it with \`xdg-open <path>\`.
- Markdown stays for what an agent reads back: code, task lists, agent briefs,
  DOX/AGENTS.md, commit messages.
- **Grilling**: every frontier round ALSO renders \`frontier.html\` with that
  round's questions and recommended answers, opened with \`xdg-open\`. The page
  is the form the user fills; the chat block stays the exchange, and the copied
  answer block goes back into the ticket as the record.
- **Wayfinder / any tracker-backed flow**: the map body, ticket bodies and the
  Decisions-so-far index stay Markdown **in the tracker** — that is the record
  the next session queries. The HTML page is the linked asset the ticket points
  at, never a replacement for it.
- If a request is really Markdown (a code answer, a short factual reply), just
  answer — this channel is for documents, not for every sentence.`;

export default function htmlArtifactsChannel(pi: ExtensionAPI) {
	pi.on("before_agent_start", (event) => {
		// Rebuilt every run, so an unchanged string produces no transcript diff.
		event.systemPromptOptions.sections.artifact_channel = CHANNEL;
	});
}

export { CHANNEL };