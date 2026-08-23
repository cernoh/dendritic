import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { execFileSync } from "node:child_process";

/** Check if tmux server is running. */
function tmuxRunning(): boolean {
  try {
    execFileSync("tmux", ["list-sessions"], { stdio: "pipe", timeout: 3000 });
    return true;
  } catch {
    return false;
  }
}

/** Run a tmux command and return stdout, or null on failure. */
function tmuxExec(args: string[]): string | null {
  try {
    return execFileSync("tmux", args, { stdio: "pipe", timeout: 5000 }).toString("utf-8");
  } catch {
    return null;
  }
}

/** Strip trailing blank lines from capture output. */
function stripTrailingBlanks(s: string): string {
  return s.replace(/\n+$/, "");
}

export default function tmuxReaderExtension(pi: ExtensionAPI) {
  pi.setLabel("Tmux Reader");
  const z = pi.zod;

  // ── tmux_sessions: discover what's running ──────────────────────
  pi.registerTool({
    name: "tmux_sessions",
    label: "Tmux Sessions",
    description:
      "List all tmux sessions, windows, and panes. Use this first to discover targets for tmux_capture. Returns session:window.pane identifiers and the running command in each pane.",
    parameters: z.object({}),
    async execute() {
      if (!tmuxRunning()) {
        return {
          content: [{ type: "text", text: "No tmux server is running. Start one with `tmux` or `tmux new -s <name>`." }],
          isError: true,
        };
      }

      // Format: session_name\twindow_index\twindow_name\tpane_index\tpane_pid\tpane_current_command\tpane_title
      const raw = tmuxExec([
        "list-panes", "-a", "-F",
        "#{session_name}\t#{window_index}\t#{window_name}\t#{pane_index}\t#{pane_pid}\t#{pane_current_command}\t#{pane_title}",
      ]);
      if (raw === null) {
        return { content: [{ type: "text", text: "Failed to list tmux panes." }], isError: true };
      }

      const lines = raw.trim().split("\n").filter(Boolean);
      if (lines.length === 0) {
        return { content: [{ type: "text", text: "No tmux panes found." }] };
      }

      const formatted = lines.map((line) => {
        const [session, winIdx, winName, paneIdx, pid, cmd, title] = line.split("\t");
        const target = `${session}:${winIdx}.${paneIdx}`;
        const titlePart = title && title !== cmd ? ` [${title}]` : "";
        return `${target}  ${winName}${titlePart}  pid=${pid}  cmd=${cmd}`;
      });

      return {
        content: [{
          type: "text",
          text: `Tmux sessions (${lines.length} pane(s)):\n\n${formatted.join("\n")}`,
        }],
      };
    },
  });

  // ── tmux_capture: read pane content ─────────────────────────────
  pi.registerTool({
    name: "tmux_capture",
    label: "Tmux Capture",
    description:
      "Capture the visible content of a tmux pane. Use for live debugging — read server logs, REPL output, running process state, etc. Target format: session:window.pane (e.g. dev:0.0). Use tmux_sessions first to discover targets.",
    parameters: z.object({
      target: z.string().describe("Tmux target pane (e.g. 'dev:0.0', '0', 'my-session:1'). Defaults to active pane."),
      lines: z.number().optional().describe("Max lines to capture from the bottom. Omit for all visible lines."),
      scrollback: z.boolean().optional().describe("Include scrollback history (default: false, visible screen only)."),
    }),
    async execute(_toolCallId, params) {
      if (!tmuxRunning()) {
        return {
          content: [{ type: "text", text: "No tmux server is running." }],
          isError: true,
        };
      }

      const target = params.target || "";
      const args = ["capture-pane", "-p"];

      if (target) {
        args.push("-t", target);
      }

      if (params.scrollback) {
        args.push("-S", "-");
        args.push("-E", "-");
      } else if (params.lines) {
        args.push("-S", `-${params.lines}`);
      }

      const raw = tmuxExec(args);
      if (raw === null) {
        const hint = target ? `Target '${target}' may not exist.` : "No active pane.";
        return {
          content: [{ type: "text", text: `Failed to capture pane. ${hint} Use tmux_sessions to list available targets.` }],
          isError: true,
        };
      }

      const text = stripTrailingBlanks(raw);
      if (!text) {
        return { content: [{ type: "text", text: `Pane ${target || "(active)"} is empty.` }] };
      }

      return {
        content: [{
          type: "text",
          text: `── tmux capture: ${target || "active"} ──\n\n${text}`,
        }],
      };
    },
  });

  // ── tmux_send_keys: send input to a pane ────────────────────────
  pi.registerTool({
    name: "tmux_send_keys",
    label: "Tmux Send Keys",
    description:
      "Send keystrokes or commands to a tmux pane. Use for interactive debugging — type commands in a REPL, send Ctrl+C to stop a process, etc. Target format: session:window.pane.",
    parameters: z.object({
      target: z.string().describe("Tmux target pane (e.g. 'dev:0.0')."),
      keys: z.string().describe("Keys to send. Literal text is typed; special keys use tmux syntax (e.g. 'C-c' for Ctrl+C, 'Enter' for newline)."),
      literal: z.boolean().optional().describe("Send keys literally (no special key interpretation). Default: false."),
    }),
    async execute(_toolCallId, params) {
      if (!tmuxRunning()) {
        return {
          content: [{ type: "text", text: "No tmux server is running." }],
          isError: true,
        };
      }

      const args = ["send-keys", "-t", params.target];
      if (params.literal) {
        args.push("-l");
      }
      args.push(params.keys);

      const result = tmuxExec(args);
      if (result === null) {
        return {
          content: [{ type: "text", text: `Failed to send keys to ${params.target}. Target may not exist.` }],
          isError: true,
        };
      }

      return {
        content: [{
          type: "text",
          text: params.literal
            ? `Sent literal text to ${params.target}: ${JSON.stringify(params.keys)}`
            : `Sent keys to ${params.target}: ${params.keys}`,
        }],
      };
    },
  });
}
