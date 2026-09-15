/**
 * html-report — the `render_html` tool.
 *
 * Purpose: turn one Markdown document into one self-contained HTML page, so the
 * user can read an interview transcript, a plan, or a report in a browser.
 *
 * Contract:
 * - Output is a single file. No external stylesheet, script, font, or image.
 * - All text is escaped. Raw HTML in the source is shown as text, never parsed.
 * - The page shell, the palette, and the theme switcher come from `lib/html.ts`,
 *   which reads the desktop palette from `<agent dir>/html-theme.json`. The page
 *   therefore carries the desktop palette, light, and dark. See that module for
 *   the palette contract.
 * - Default output path: `<agent dir>/html/<slug>-<stamp>.html`, where the agent
 *   dir is `PI_CODING_AGENT_DIR` or `~/.omp/agent`. That path stays untracked,
 *   because `home/.gitignore` ignores `agent/*` except tracked config.
 * - `render_html` never writes anywhere except the output path it reports.
 *
 * The question and recommendation format of the `grilling` skill gets its own
 * card layout, so the transcript reads as a list of decisions.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, extname, isAbsolute, join, resolve } from "node:path";
import {
  agentDir,
  escapeHtml,
  humanDate,
  openInBrowser,
  pageShell,
  safeUrl,
  slugify,
  stamp,
  themeOptions,
} from "./lib/html";

// --------------------------------------------------------------------------
// Inline Markdown
// --------------------------------------------------------------------------

function renderInlinePlain(text: string): string {
  let out = escapeHtml(text);
  out = out.replace(/!\[([^\]]*)\]\(([^)\s]+)(?:\s+&quot;[^&]*&quot;)?\)/g, (_m, alt: string, src: string) => {
    return `<img src="${safeUrl(src)}" alt="${alt}">`;
  });
  out = out.replace(/\[([^\]]+)\]\(([^)\s]+)(?:\s+&quot;[^&]*&quot;)?\)/g, (_m, label: string, href: string) => {
    return `<a href="${safeUrl(href)}">${label}</a>`;
  });
  out = out.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  out = out.replace(/__([^_]+)__/g, "<strong>$1</strong>");
  out = out.replace(/(^|[\s(])\*([^*\s][^*]*)\*/g, "$1<em>$2</em>");
  out = out.replace(/(^|[\s(])_([^_\s][^_]*)_/g, "$1<em>$2</em>");
  out = out.replace(/~~([^~]+)~~/g, "<del>$1</del>");
  return out;
}

function renderInline(text: string): string {
  return text
    .split(/(`[^`]+`)/g)
    .map((part) => {
      if (part.length > 1 && part.startsWith("`") && part.endsWith("`")) {
        return `<code>${escapeHtml(part.slice(1, -1))}</code>`;
      }
      return renderInlinePlain(part);
    })
    .join("");
}

// --------------------------------------------------------------------------
// Block Markdown
// --------------------------------------------------------------------------

interface ListItem {
  depth: number;
  text: string;
  task?: boolean;
  checked?: boolean;
}

type Block =
  | { kind: "frontmatter"; entries: [string, string][] }
  | { kind: "heading"; level: number; text: string; id: string }
  | { kind: "paragraph"; text: string }
  | { kind: "code"; lang: string; code: string }
  | { kind: "list"; ordered: boolean; items: ListItem[] }
  | { kind: "quote"; text: string }
  | { kind: "rule" }
  | { kind: "table"; head: string[]; rows: string[][] }
  | { kind: "question"; label: string; title: string; body: string; answer?: string };

const FENCE_RE = /^\s*(?:`{3,}|~{3,})\s*([\w+#.-]*)\s*$/;
const HEADING_RE = /^(#{1,6})\s+(.*?)\s*#*\s*$/;
const RULE_RE = /^\s*(?:-{3,}|\*{3,}|_{3,})\s*$/;
const QUOTE_RE = /^\s*>\s?(.*)$/;
const LIST_RE = /^(\s*)(?:([-*+])|(\d+)[.)])\s+(.*)$/;
const TABLE_SEP_RE = /^\s*\|?[\s:|-]+\|?\s*$/;
const QUESTION_RE = /^❓\s*(.+)$/s;
const ANSWER_RE = /^➡️?\s*(.+)$/s;

function splitRow(line: string): string[] {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  return trimmed.split("|").map((cell) => cell.trim());
}

/** Read the `key: value` frontmatter block, and unfold `>` and `|` values. */
function parseFrontmatter(lines: string[]): [string, string][] {
  const entries: [string, string][] = [];
  let index = 0;
  while (index < lines.length) {
    const line = lines[index];
    const match = /^([A-Za-z0-9_-]+):\s*(.*)$/.exec(line);
    if (!match) {
      index += 1;
      continue;
    }
    const key = match[1];
    let value = match[2].trim();
    index += 1;
    if (value === ">" || value === "|" || value === "") {
      const folded: string[] = [];
      while (index < lines.length && /^\s+\S/.test(lines[index])) {
        folded.push(lines[index].trim());
        index += 1;
      }
      const joined = folded.join(value === "|" ? "\n" : " ").trim();
      if (joined) value = joined;
    }
    if (value) entries.push([key, value]);
  }
  return entries;
}

function questionFrom(text: string): { label: string; title: string; body: string } {
  const head = /^\*\*([^*]+)\*\*\s*[-–—:]?\s*(?:\*\*([^*]+)\*\*\s*:?)?\s*(.*)$/s.exec(text);
  if (head) {
    return {
      label: head[1].trim(),
      title: (head[2] ?? head[1]).trim(),
      body: (head[3] ?? "").trim(),
    };
  }
  const colon = text.indexOf(":");
  if (colon > 0 && colon < 120) {
    return { label: "Q", title: text.slice(0, colon).trim(), body: text.slice(colon + 1).trim() };
  }
  return { label: "Q", title: text.slice(0, 80).trim(), body: text.slice(80).trim() };
}

function parseMarkdown(markdown: string): Block[] {
  const lines = markdown.replace(/\r\n?/g, "\n").split("\n");
  const blocks: Block[] = [];
  const usedIds = new Map<string, number>();
  let index = 0;

  const pushHeading = (level: number, text: string) => {
    const base = slugify(text);
    const seen = usedIds.get(base) ?? 0;
    usedIds.set(base, seen + 1);
    blocks.push({ kind: "heading", level, text, id: seen === 0 ? base : `${base}-${seen}` });
  };

  // Leading frontmatter block.
  if (lines[0]?.trim() === "---") {
    const end = lines.findIndex((line, position) => position > 0 && line.trim() === "---");
    if (end > 1) {
      const entries = parseFrontmatter(lines.slice(1, end));
      if (entries.length > 0) blocks.push({ kind: "frontmatter", entries });
      index = end + 1;
    }
  }

  while (index < lines.length) {
    const line = lines[index];

    if (!line.trim()) {
      index += 1;
      continue;
    }

    const fence = FENCE_RE.exec(line);
    if (fence) {
      const lang = fence[1] ?? "";
      const body: string[] = [];
      index += 1;
      while (index < lines.length && !FENCE_RE.test(lines[index])) {
        body.push(lines[index]);
        index += 1;
      }
      index += 1;
      blocks.push({ kind: "code", lang, code: body.join("\n") });
      continue;
    }

    const heading = HEADING_RE.exec(line);
    if (heading) {
      pushHeading(heading[1].length, heading[2]);
      index += 1;
      continue;
    }

    if (RULE_RE.test(line)) {
      blocks.push({ kind: "rule" });
      index += 1;
      continue;
    }

    if (QUOTE_RE.test(line)) {
      const body: string[] = [];
      while (index < lines.length) {
        const quoted = QUOTE_RE.exec(lines[index]);
        if (!quoted) break;
        body.push(quoted[1]);
        index += 1;
      }
      blocks.push({ kind: "quote", text: body.join("\n").trim() });
      continue;
    }

    const list = LIST_RE.exec(line);
    if (list) {
      const ordered = Boolean(list[3]);
      const items: ListItem[] = [];
      while (index < lines.length) {
        const current = LIST_RE.exec(lines[index]);
        if (!current || Boolean(current[3]) !== ordered) break;
        const depth = Math.min(3, Math.floor(current[1].replace(/\t/g, "  ").length / 2));
        let text = current[4].trim();
        let task: boolean | undefined;
        let checked: boolean | undefined;
        const box = /^\[([ xX])\]\s*(.*)$/.exec(text);
        if (box) {
          task = true;
          checked = box[1].toLowerCase() === "x";
          text = box[2];
        }
        items.push({ depth, text, task, checked });
        index += 1;
      }
      blocks.push({ kind: "list", ordered, items });
      continue;
    }

    if (line.includes("|") && index + 1 < lines.length && TABLE_SEP_RE.test(lines[index + 1])) {
      const head = splitRow(line);
      const rows: string[][] = [];
      index += 2;
      while (index < lines.length && lines[index].includes("|") && lines[index].trim()) {
        rows.push(splitRow(lines[index]));
        index += 1;
      }
      blocks.push({ kind: "table", head, rows });
      continue;
    }

    const paragraph: string[] = [];
    while (index < lines.length && lines[index].trim() && !isBlockStart(lines[index], lines[index + 1])) {
      paragraph.push(lines[index].trim());
      index += 1;
    }
    if (paragraph.length > 0) {
      const text = paragraph.join("\n");
      const question = QUESTION_RE.exec(text);
      const answer = ANSWER_RE.exec(text);
      if (question) {
        const parsed = questionFrom(question[1].trim());
        blocks.push({ kind: "question", label: parsed.label, title: parsed.title, body: parsed.body });
      } else if (answer) {
        blocks.push({ kind: "paragraph", text: `➡️ ${answer[1]}` });
      } else {
        blocks.push({ kind: "paragraph", text });
      }
      continue;
    }

    index += 1;
  }

  return groupQuestions(blocks);
}

function isBlockStart(line: string, next?: string): boolean {
  if (FENCE_RE.test(line) || HEADING_RE.test(line) || RULE_RE.test(line)) return true;
  if (QUOTE_RE.test(line) || LIST_RE.test(line)) return true;
  return Boolean(next && line.includes("|") && TABLE_SEP_RE.test(next));
}

/** Pair each question with the recommendation that follows it. */
function groupQuestions(blocks: Block[]): Block[] {
  const out: Block[] = [];
  for (let index = 0; index < blocks.length; index += 1) {
    const block = blocks[index];
    if (block.kind !== "question") {
      out.push(block);
      continue;
    }
    let cursor = index + 1;
    if (blocks[cursor]?.kind === "rule") cursor += 1;
    const next = blocks[cursor];
    if (next && next.kind === "paragraph" && next.text.trimStart().startsWith("➡️")) {
      out.push({ ...block, answer: next.text.trimStart().replace(ANSWER_RE, "$1").trim() });
      index = cursor;
      continue;
    }
    out.push(block);
  }
  return out;
}

// --------------------------------------------------------------------------
// Rendering
// --------------------------------------------------------------------------

function renderListItem(item: ListItem, ordered: boolean, position: number): string {
  const marker = ordered ? `${position}.` : "•";
  const box = item.task ? `<span class="box">${item.checked ? "☑" : "☐"}</span> ` : "";
  const markerHtml = item.task ? box : `<span class="marker">${marker}</span> `;
  return `<li data-depth="${item.depth}"${item.checked ? ' class="done"' : ""}>${markerHtml}${renderInline(item.text)}</li>`;
}

function renderTable(block: { head: string[]; rows: string[][] }): string {
  const head = block.head.map((cell) => `<th>${renderInline(cell)}</th>`).join("");
  const rows = block.rows
    .map((row) => `<tr>${row.map((cell) => `<td>${renderInline(cell)}</td>`).join("")}</tr>`)
    .join("");
  return `<div class="table-wrap"><table><thead><tr>${head}</tr></thead><tbody>${rows}</tbody></table></div>`;
}

function renderBlocks(blocks: Block[]): string {
  const out: string[] = [];
  for (let index = 0; index < blocks.length; index += 1) {
    const block = blocks[index];
    switch (block.kind) {
      case "frontmatter":
        out.push(
          `<div class="card meta"><dl>${block.entries
            .map(([key, value]) => `<dt>${escapeHtml(key)}</dt><dd>${renderInline(value)}</dd>`)
            .join("")}</dl></div>`,
        );
        break;
      case "heading": {
        if (block.level === 1) break; // the page header owns the title
        const rendered = renderInline(block.text);
        out.push(`<h${block.level} id="${block.id}">${rendered}</h${block.level}>`);
        break;
      }
      case "paragraph":
        out.push(`<p>${renderInline(block.text)}</p>`);
        break;
      case "code":
        out.push(
          `<pre${block.lang ? ` data-lang="${escapeHtml(block.lang)}"` : ""}><code>${escapeHtml(block.code)}</code></pre>`,
        );
        break;
      case "list": {
        const tag = block.ordered ? "ol" : "ul";
        const items = block.items
          .map((item, position) => renderListItem(item, block.ordered, position + 1))
          .join("");
        out.push(`<${tag} class="list">${items}</${tag}>`);
        break;
      }
      case "quote":
        out.push(
          `<blockquote>${block.text
            .split("\n")
            .map((line) => `<p>${renderInline(line)}</p>`)
            .join("")}</blockquote>`,
        );
        break;
      case "rule": {
        const previous = blocks[index - 1];
        const next = blocks[index + 1];
        if (previous?.kind === "question" || next?.kind === "question") break;
        out.push("<hr>");
        break;
      }
      case "table":
        out.push(renderTable(block));
        break;
      case "question":
        out.push(
          `<article class="card q">` +
            `<p class="q-label">❓ ${escapeHtml(block.label)}</p>` +
            `<p class="q-title">${renderInline(block.title)}</p>` +
            (block.body
              ? `<div class="q-body">${block.body
                  .split("\n\n")
                  .map((part) => `<p>${renderInline(part.replace(/\n/g, " "))}</p>`)
                  .join("")}</div>`
              : "") +
            (block.answer
              ? `<div class="q-answer"><p class="q-answer-label">➡️ recommended</p><p>${renderInline(
                  block.answer.replace(/\n/g, " "),
                )}</p></div>`
              : "") +
            `</article>`,
        );
        break;
    }
  }
  return out.join("\n");
}

function collectHeadings(blocks: Block[]): { id: string; text: string; level: number }[] {
  return blocks
    .filter((block): block is Extract<Block, { kind: "heading" }> => block.kind === "heading" && block.level <= 3)
    .map((block) => ({ id: block.id, text: block.text, level: block.level }));
}

function firstHeading(blocks: Block[]): string | undefined {
  const heading = blocks.find((block) => block.kind === "heading" && block.level === 1);
  return heading && heading.kind === "heading" ? heading.text : undefined;
}

// --------------------------------------------------------------------------
// Palettes
// --------------------------------------------------------------------------

/**
 * Document layout. The shell, the palette, and the theme switcher come from
 * `lib/html.ts`; this constant holds only the rules of a rendered document.
 */
const DOCUMENT_CSS = `
h2 {
  margin: 44px 0 14px;
  padding-top: 18px;
  border-top: 1px solid var(--line);
  font-family: var(--serif);
  font-size: 23px;
  font-weight: 500;
}
h3 { margin: 30px 0 10px; font-size: 16.5px; font-weight: 600; }
h4, h5, h6 { margin: 24px 0 8px; font-size: 14px; font-weight: 600; color: var(--muted); }
p { margin: 0 0 14px; }
a { color: var(--link); text-decoration-thickness: 1px; text-underline-offset: 2px; }
strong { font-weight: 650; }
del { color: var(--danger); }
img { max-width: 100%; border-radius: 8px; }
hr { border: 0; border-top: 1px dashed var(--line); margin: 32px 0; }
.card {
  background: var(--card);
  border: 1.5px solid var(--line);
  border-radius: 10px;
  padding: 20px 22px;
  margin: 0 0 18px;
}
code {
  font-family: var(--mono);
  font-size: 0.88em;
  background: var(--code-background);
  color: var(--code-ink);
  border-radius: 4px;
  padding: 1px 5px;
}
pre {
  margin: 0 0 18px;
  padding: 14px 16px;
  background: var(--code-background);
  border: 1px solid var(--line);
  border-radius: 8px;
  overflow-x: auto;
}
pre code { background: none; color: var(--ink); padding: 0; font-size: 12.5px; line-height: 1.55; }
pre[data-lang]::before {
  content: attr(data-lang);
  display: block;
  margin-bottom: 8px;
  font-family: var(--mono);
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--faint);
}
blockquote {
  margin: 0 0 18px;
  padding: 2px 0 2px 16px;
  border-left: 3px solid var(--accent);
  color: var(--quote-ink);
}
blockquote p:last-child { margin-bottom: 0; }
ul.list, ol.list { margin: 0 0 18px; }
ul.list { list-style: none; padding-left: 4px; }
ul.list li, ol.list li { margin: 6px 0; }
ul.list li[data-depth="1"] { margin-left: 20px; }
ul.list li[data-depth="2"] { margin-left: 40px; }
ul.list li[data-depth="3"] { margin-left: 60px; }
ol.list { list-style: none; counter-reset: item; padding-left: 4px; }
ol.list li { counter-increment: item; }
.marker { font-family: var(--mono); font-size: 12px; color: var(--accent); }
ul.list li.done { color: var(--faint); text-decoration: line-through; }
.box { font-family: var(--mono); color: var(--accent); }
.table-wrap { overflow-x: auto; margin: 0 0 18px; }
table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
th {
  text-align: left;
  font-family: var(--mono);
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--faint);
  border-bottom: 1.5px solid var(--line-strong);
  padding: 8px 10px;
}
td { padding: 9px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }
tr:last-child td { border-bottom: 0; }
.card.meta dl { display: grid; grid-template-columns: minmax(90px, max-content) 1fr; gap: 4px 18px; margin: 0; }
.card.meta dt {
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--faint);
  padding-top: 3px;
}
.card.meta dd { margin: 0; font-size: 14px; }
.toc { margin: 26px 0 30px; }
.toc p {
  margin: 0 0 10px;
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--faint);
}
.toc ol { margin: 0; padding: 0; list-style: none; display: grid; gap: 4px; }
.toc li[data-level="3"] { padding-left: 18px; }
.toc a { color: var(--ink); text-decoration: none; font-size: 13.5px; }
.toc a:hover { color: var(--accent); text-decoration: underline; }
article.q { break-inside: avoid; }
.q-label {
  margin: 0 0 6px;
  font-family: var(--mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--accent);
}
.q-title { margin: 0 0 10px; font-family: var(--serif); font-size: 18px; font-weight: 500; }
.q-body p:last-child { margin-bottom: 0; }
.q-answer {
  margin: 16px 0 0;
  padding: 12px 0 0 16px;
  border-left: 3px solid var(--success);
  border-top: 1px dashed var(--line);
}
.q-answer-label {
  margin: 0 0 4px;
  font-family: var(--mono);
  font-size: 10.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--success);
}
.q-answer p:last-child { margin-bottom: 0; }
@media (max-width: 700px) {
  h2 { font-size: 20px; }
  .card { padding: 16px; }
}
@media print {
  article.q, .card { break-inside: avoid; }
}
`;

interface RenderInput {
  markdown: string;
  title?: string;
  source: string;
  theme?: string;
}

interface RenderOutput {
  html: string;
  title: string;
  headings: number;
  questions: number;
  themes: string[];
}

function renderDocument(input: RenderInput): RenderOutput {
  const options = themeOptions();
  const blocks = parseMarkdown(input.markdown);
  const title = input.title?.trim() || firstHeading(blocks) || basename(input.source, extname(input.source)) || "Document";
  const headings = collectHeadings(blocks);
  const questions = blocks.filter((block) => block.kind === "question").length;
  const body = renderBlocks(blocks);
  const words = input.markdown.split(/\s+/).filter(Boolean).length;

  const toc =
    headings.length >= 2
      ? `<nav class="toc card"><p>Contents</p><ol>${headings
          .map(
            (heading) =>
              `<li data-level="${heading.level}"><a href="#${heading.id}">${renderInline(heading.text)}</a></li>`,
          )
          .join("")}</ol></nav>`
      : "";

  const meta = [`${words} words`, questions > 0 ? `${questions} questions` : "", humanDate()].filter(Boolean).join(" · ");

  const html = pageShell({
    eyebrow: input.source,
    heading: title,
    headingHtml: renderInline(title),
    sub: meta,
    style: DOCUMENT_CSS,
    defaultTheme: input.theme,
    body: `${toc}
<main>
${body}
</main>`,
    footer: [input.source, humanDate(), "render_html · oh-my-pi"],
  });

  return { html, title, headings: headings.length, questions, themes: options.map((option) => option.id) };
}

// --------------------------------------------------------------------------
// Tool
// --------------------------------------------------------------------------

interface RenderParams {
  path?: string;
  markdown?: string;
  title?: string;
  out?: string;
  open?: boolean;
  theme?: string;
}

export default function htmlReportExtension(pi: ExtensionAPI) {
  const z = pi.zod;

  pi.setLabel("HTML Report");

  pi.registerTool({
    name: "render_html",
    label: "Render HTML",
    description:
      "Render a Markdown document as one self-contained HTML page, and write it to disk. " +
      "Use it to show a Markdown file or a Markdown string in a browser: an interview transcript, a plan, a report, " +
      "or the record of a grilling session. The page holds its own CSS and script, so it needs no network. " +
      "It renders headings, lists, tables, code blocks, blockquotes, and the question and recommendation card " +
      "format of the grilling skill. The page carries the desktop palette, plus light and dark. Returns the output path.",
    parameters: z.object({
      path: z.string().optional().describe("Path to a Markdown file to render. Use this or markdown."),
      markdown: z.string().optional().describe("Markdown text to render. Use this or path."),
      title: z.string().optional().describe("Page title. Defaults to the first heading or the file name."),
      out: z
        .string()
        .optional()
        .describe("Output HTML path. A relative path resolves against the working directory."),
      open: z.boolean().optional().describe("Open the page in the default browser after the write. Default false."),
      theme: z.string().optional().describe("Theme the page opens with: desktop, light, or dark. Default desktop."),
    }),
    loadMode: "essential",
    approval: "write",
    async execute(_toolCallId, params: RenderParams, signal, _onUpdate, ctx) {
      if (signal?.aborted) {
        return { content: [{ type: "text", text: "Cancelled." }] };
      }

      const pathParam =
        typeof params.path === "string" && params.path.trim().length > 0 ? params.path.trim() : undefined;
      const markdownParam =
        typeof params.markdown === "string" && params.markdown.length > 0 ? params.markdown : undefined;
      if (pathParam && markdownParam) throw new Error("Pass either path or markdown, not both.");

      let markdown: string;
      let source: string;
      let slug: string;

      if (pathParam) {
        const file = isAbsolute(pathParam) ? pathParam : resolve(ctx.cwd, pathParam);
        if (!existsSync(file)) throw new Error(`No such file: ${file}`);
        if (statSync(file).isDirectory()) throw new Error(`Not a file: ${file}`);
        markdown = readFileSync(file, "utf8");
        source = basename(file);
        slug = slugify(basename(file, extname(file)));
      } else if (markdownParam) {
        markdown = markdownParam;
        source = "inline markdown";
        slug = slugify(params.title ?? markdown.split("\n")[0]?.replace(/^#+\s*/, "") ?? "document");
      } else {
        throw new Error("Pass path or markdown.");
      }

      const rendered = renderDocument({ markdown, title: params.title, source, theme: params.theme });
      if (params.theme && !rendered.themes.includes(params.theme)) {
        throw new Error(`Unknown theme "${params.theme}". Use one of: ${rendered.themes.join(", ")}.`);
      }

      const out = params.out?.trim()
        ? resolve(ctx.cwd, params.out.trim())
        : join(agentDir(), "html", `${slug}-${stamp()}.html`);

      mkdirSync(dirname(out), { recursive: true });
      writeFileSync(out, rendered.html, "utf8");
      if (params.open) openInBrowser(out);

      return {
        content: [
          {
            type: "text",
            text:
              `Wrote ${out} (${rendered.html.length} bytes, ${rendered.headings} headings, ` +
              `${rendered.questions} questions, themes: ${rendered.themes.join(", ")}). Title: ${rendered.title}.`,
          },
        ],
        details: {
          path: out,
          bytes: rendered.html.length,
          title: rendered.title,
          headings: rendered.headings,
          questions: rendered.questions,
          themes: rendered.themes,
          opened: Boolean(params.open),
        },
      };
    },
  });
}
