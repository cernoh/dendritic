/**
 * Shared plumbing for the omp HTML tools.
 *
 * Purpose: one place for the page shell, the palettes, the theme switcher, the
 * text escaping, and the browser opener, used by `html-report.ts` (the
 * `render_html` tool) and `grill-form.ts` (the `grill_form` and `grill_finish`
 * tools).
 *
 * Contract:
 * - This module lives in `extensions/lib/`, so omp's extension scan does not
 *   load it as an extension of its own.
 * - The palette has one source: `<agent dir>/html-theme.json`, which
 *   `home.activation.ompHtmlTheme` writes from `self.scheme.html`. The page
 *   then carries three themes: that desktop palette, light, and dark.
 * - Every color that arrives from a file is validated as a hex literal before
 *   it reaches the CSS, so a foreign file cannot inject a rule.
 * - `escapeHtml` is the only way source text reaches the page. Raw HTML in a
 *   source document is shown as text.
 */
import { spawn } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

export interface DesktopTheme {
  label: string;
  mode: string;
  colors: Record<string, string>;
}

export interface ThemeOption {
  id: string;
  label: string;
}

export interface PageShellInput {
  /** Short label above the heading, for example the source file name. */
  eyebrow: string;
  heading: string;
  /** Pre-rendered heading HTML, for callers that render inline Markdown. */
  headingHtml?: string;
  sub: string;
  /** Page-specific layout CSS. The palette CSS is added on top of it. */
  style: string;
  /** Outer HTML for the page body. */
  body: string;
  /** Optional page-specific script, after the shared theme script. */
  script?: string;
  /** Footer cells. */
  footer: string[];
  /** Theme the page opens with. Defaults to the desktop palette when it exists. */
  defaultTheme?: string;
}

const HTML_ESCAPES: Record<string, string> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
  "'": "&#39;",
};

export function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (char) => HTML_ESCAPES[char] ?? char);
}

/** Block `javascript:` and `data:` URLs, and keep the rest. */
export function safeUrl(url: string): string {
  const trimmed = url.trim();
  if (/^(?:javascript|data|vbscript):/i.test(trimmed)) return "#";
  return trimmed;
}

export function slugify(text: string): string {
  const slug = text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
  return slug || "section";
}

/** Local time stamp: `20260915-180233`. */
export function stamp(date = new Date()): string {
  const pad = (value: number) => String(value).padStart(2, "0");
  return (
    `${date.getFullYear()}${pad(date.getMonth() + 1)}${pad(date.getDate())}` +
    `-${pad(date.getHours())}${pad(date.getMinutes())}${pad(date.getSeconds())}`
  );
}

export function humanDate(date = new Date()): string {
  return date.toISOString().replace("T", " ").slice(0, 16) + " UTC";
}

export function agentDir(): string {
  const configured = process.env.PI_CODING_AGENT_DIR;
  if (configured && configured.trim()) return resolve(configured.trim());
  return join(process.env.HOME?.trim() || homedir(), ".omp", "agent");
}

/**
 * Read the desktop palette that `home.activation.ompHtmlTheme` writes from
 * `self.scheme.html`. Every color must be a hex literal. An unreadable file
 * yields undefined, and the page then offers light and dark only.
 */
export function readDesktopTheme(): DesktopTheme | undefined {
  const file = join(agentDir(), "html-theme.json");
  if (!existsSync(file)) return undefined;
  let parsed: unknown;
  try {
    parsed = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    return undefined;
  }
  if (!parsed || typeof parsed !== "object") return undefined;
  const document = parsed as { name?: unknown; mode?: unknown; colors?: unknown };
  if (!document.colors || typeof document.colors !== "object") return undefined;
  const colors: Record<string, string> = {};
  for (const [key, value] of Object.entries(document.colors as Record<string, unknown>)) {
    if (typeof value !== "string" || !/^#[0-9a-fA-F]{3,8}$/.test(value)) continue;
    colors[key] = value;
  }
  if (Object.keys(colors).length < 5) return undefined;
  return {
    label: typeof document.name === "string" && document.name.trim() ? document.name.trim() : "desktop",
    mode: document.mode === "light" ? "light" : "dark",
    colors,
  };
}

/**
 * The CSS custom properties both pages draw with. The light set is the
 * `show-html` pack palette; the dark set is its neutral counterpart; the
 * desktop set arrives from the scheme document.
 */
export const PALETTE_CSS = `:root {
  color-scheme: light;
  --background: #FAF9F5;
  --card: #FFFFFF;
  --raised: #F0EEE6;
  --ink: #141413;
  --muted: #3D3D3A;
  --faint: #87867F;
  --line: #D1CFC5;
  --line-strong: #87867F;
  --accent: #D97757;
  --on-accent: #FFFFFF;
  --link: #B04A3F;
  --success: #788C5D;
  --danger: #B04A3F;
  --code-background: #F0EEE6;
  --code-ink: #3D3D3A;
  --quote-ink: #3D3D3A;
  --selection: #E3DACC;
  --selection-ink: #141413;
  --serif: ui-serif, Georgia, "Times New Roman", serif;
  --sans: system-ui, -apple-system, "Segoe UI", sans-serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}
html[data-theme="dark"] {
  color-scheme: dark;
  --background: #141413;
  --card: #1C1C1A;
  --raised: #24231F;
  --ink: #F0EEE6;
  --muted: #C7C5BA;
  --faint: #A5A39A;
  --line: #35342F;
  --line-strong: #4C4A44;
  --accent: #E08B6D;
  --on-accent: #1C1C1A;
  --link: #E0A184;
  --success: #9AAE72;
  --danger: #D97F6C;
  --code-background: #24231F;
  --code-ink: #F0DDBE;
  --quote-ink: #C7C5BA;
  --selection: #3C3A34;
  --selection-ink: #F7F2E8;
}`;

function desktopThemeCss(theme: DesktopTheme): string {
  const declarations = Object.entries(theme.colors)
    .map(([key, value]) => `  --${key.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase()}: ${value};`)
    .join("\n");
  return `html[data-theme="desktop"] {\n  color-scheme: ${theme.mode};\n${declarations}\n}`;
}

/** Palette CSS plus one block per available theme, for a `<style>` element. */
export function paletteCss(): string {
  const desktop = readDesktopTheme();
  return desktop ? `${PALETTE_CSS}\n${desktopThemeCss(desktop)}` : PALETTE_CSS;
}

export function themeOptions(): ThemeOption[] {
  const desktop = readDesktopTheme();
  const options: ThemeOption[] = [];
  if (desktop) options.push({ id: "desktop", label: desktop.label });
  options.push({ id: "light", label: "light" }, { id: "dark", label: "dark" });
  return options;
}

/** The theme the page opens with: the desktop palette when it exists. */
export function defaultTheme(options: ThemeOption[]): string {
  return options.some((option) => option.id === "desktop") ? "desktop" : "light";
}

export function themeSwitcher(options: ThemeOption[]): string {
  return `<div class="theme-switch" role="group" aria-label="Theme">${options
    .map(
      (option) =>
        `<button type="button" data-theme-id="${option.id}" aria-pressed="false">${escapeHtml(option.label)}</button>`,
    )
    .join("")}</div>`;
}

/** Applies the stored or default theme before the first paint, and wires the buttons. */
export const THEME_SCRIPT = `(function () {
  var root = document.documentElement;
  var available = (root.dataset.themes || "light dark").split(" ");
  var key = "omp-html-theme";
  var stored = null;
  try { stored = window.localStorage.getItem(key); } catch (error) {}
  var chosen = stored && available.indexOf(stored) >= 0 ? stored : root.dataset.defaultTheme;
  if (available.indexOf(chosen) < 0) chosen = available[0];
  root.dataset.theme = chosen;
  document.addEventListener("DOMContentLoaded", function () {
    var buttons = document.querySelectorAll(".theme-switch button");
    var paint = function () {
      for (var index = 0; index < buttons.length; index += 1) {
        var active = buttons[index].dataset.themeId === root.dataset.theme;
        buttons[index].classList.toggle("active", active);
        buttons[index].setAttribute("aria-pressed", active ? "true" : "false");
      }
    };
    for (var index = 0; index < buttons.length; index += 1) {
      buttons[index].addEventListener("click", function (event) {
        root.dataset.theme = event.currentTarget.dataset.themeId;
        try { window.localStorage.setItem(key, root.dataset.theme); } catch (error) {}
        paint();
      });
    }
    paint();
  });
})();`;

/** Shell layout shared by every generated page. */
export const SHELL_CSS = `* { box-sizing: border-box; }
html { -webkit-text-size-adjust: 100%; }
body {
  margin: 0;
  background: var(--background);
  color: var(--ink);
  font-family: var(--sans);
  font-size: 15px;
  line-height: 1.6;
}
::selection { background: var(--selection); color: var(--selection-ink); }
.page { max-width: 880px; margin: 0 auto; padding: 56px 28px 80px; }
.doc-head { position: relative; padding-bottom: 8px; }
.eyebrow {
  margin: 0;
  font-family: var(--mono);
  font-size: 11.5px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--faint);
  overflow-wrap: anywhere;
}
h1 {
  margin: 10px 0 8px;
  font-family: var(--serif);
  font-size: 34px;
  font-weight: 500;
  line-height: 1.2;
}
.sub { margin: 0; font-size: 13px; color: var(--faint); }
.theme-switch {
  position: absolute;
  top: 0;
  right: 0;
  display: flex;
  gap: 2px;
  padding: 3px;
  border: 1.5px solid var(--line);
  border-radius: 999px;
  background: var(--card);
}
.theme-switch button {
  border: 0;
  border-radius: 999px;
  background: none;
  color: var(--faint);
  font-family: var(--mono);
  font-size: 11px;
  letter-spacing: 0.04em;
  padding: 4px 10px;
  cursor: pointer;
}
.theme-switch button:hover { color: var(--ink); }
.theme-switch button.active { background: var(--accent); color: var(--on-accent); }
footer.doc-foot {
  margin-top: 56px;
  padding-top: 16px;
  border-top: 1px solid var(--line);
  display: flex;
  flex-wrap: wrap;
  gap: 8px 20px;
  font-family: var(--mono);
  font-size: 11.5px;
  color: var(--faint);
  overflow-wrap: anywhere;
}
@media (max-width: 700px) {
  .page { padding: 38px 18px 60px; }
  h1 { font-size: 26px; }
  .doc-head { padding-bottom: 46px; }
  .theme-switch { top: auto; bottom: 0; right: auto; left: 0; }
}
@media print {
  .theme-switch { display: none; }
  .page { max-width: none; padding: 0; }
}`;

export function pageShell(input: PageShellInput): string {
  const options = themeOptions();
  const footer = input.footer.map((cell) => `<span>${escapeHtml(cell)}</span>`).join("");
  const chosen =
    input.defaultTheme && options.some((option) => option.id === input.defaultTheme)
      ? input.defaultTheme
      : defaultTheme(options);
  return `<!DOCTYPE html>
<html lang="en" data-default-theme="${chosen}" data-themes="${options.map((option) => option.id).join(" ")}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(input.heading)}</title>
<style>${SHELL_CSS}
${paletteCss()}
${input.style}
</style>
<script>${THEME_SCRIPT}</script>
</head>
<body>
<div class="page">
<header class="doc-head">
<p class="eyebrow">${escapeHtml(input.eyebrow)}</p>
<h1>${input.headingHtml ?? escapeHtml(input.heading)}</h1>
<p class="sub">${escapeHtml(input.sub)}</p>
${themeSwitcher(options)}
</header>
${input.body}
<footer class="doc-foot">
${footer}
</footer>
</div>
${input.script ? `<script>${input.script}</script>` : ""}
</body>
</html>
`;
}

export function openInBrowser(path: string): void {
  const command = process.platform === "darwin" ? "open" : "xdg-open";
  try {
    spawn(command, [path], { detached: true, stdio: "ignore" }).unref();
  } catch {
    // A missing opener must not fail the call.
  }
}
