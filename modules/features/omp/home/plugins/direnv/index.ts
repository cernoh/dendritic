import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { execSync } from "node:child_process";
import { existsSync, statSync } from "node:fs";
import { dirname, join } from "node:path";

/** Result of loading direnv environment from a directory. */
interface DirenvEnv {
  /** Directory where .envrc/.env was found. */
  rcDir: string;
  /** Parsed environment variables from direnv export. */
  envVars: Record<string, string>;
  /** Raw shell export output (for debugging). */
  rawExport: string;
}

/** Cached direnv environment for the current session. */
let cachedEnv: DirenvEnv | null = null;
let direnvAvailable = false;

/**
 * Check if direnv is installed and executable.
 */
function checkDirenvAvailable(): boolean {
  try {
    execSync("which direnv", { stdio: "pipe" });
    return true;
  } catch {
    return false;
  }
}

/**
 * Walk up from startDir looking for .envrc or .env file.
 * Returns the directory containing the first found file, or null.
 */
function findRcDir(startDir: string): string | null {
  let current = startDir;
  const root = "/";

  while (true) {
    if (existsSync(join(current, ".envrc"))) {
      return current;
    }
    if (existsSync(join(current, ".env"))) {
      return current;
    }
    if (current === root) break;
    const parent = dirname(current);
    if (parent === current) break; // reached root
    current = parent;
  }
  return null;
}

/**
 * Parse `direnv export bash` output to extract environment variables.
 * Output format: export KEY=$'value';export KEY2=$'value2';...
 * Also handles: export KEY="value"; and export KEY=value;
 */
function parseDirenvExport(raw: string): Record<string, string> {
  const envVars: Record<string, string> = {};

  // Match export statements: export KEY=VALUE;
  // Handles: export KEY=$'value'; export KEY="value"; export KEY=value;
  const exportRegex = /export\s+([A-Za-z_][A-Za-z0-9_]*)=(.+?);/g;
  let match;

  while ((match = exportRegex.exec(raw)) !== null) {
    const key = match[1];
    let value = match[2];

    // Skip internal direnv variables - we only care about user-defined env vars
    if (key.startsWith("DIRENV_")) continue;

    // Handle $'...' bash quoting (with escape sequences)
    if (value.startsWith("$'") && value.endsWith("'")) {
      value = value.slice(2, -1);
      // Unescape common bash escape sequences
      value = value
        .replace(/\\n/g, "\n")
        .replace(/\\t/g, "\t")
        .replace(/\\'/g, "'")
        .replace(/\\\\/g, "\\");
    }
    // Handle "..." quoting
    else if (value.startsWith('"') && value.endsWith('"')) {
      value = value.slice(1, -1);
    }
    // Handle plain unquoted value
    else {
      // Remove trailing whitespace/newlines
      value = value.trim();
    }

    envVars[key] = value;
  }

  return envVars;
}

/**
 * Load direnv environment for the given directory.
 * Returns null if direnv is not available, no .envrc found, or not allowed.
 */
function loadDirenvEnv(rcDir: string): DirenvEnv | null {
  try {
    // Run direnv export bash to get the environment diff
    const rawExport = execSync(`direnv export bash`, {
      cwd: rcDir,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "pipe"],
      // direnv may print status to stderr (e.g., "direnv: loading ...")
      // We capture both stdout and stderr
    });

    const envVars = parseDirenvExport(rawExport);

    // Only return if we actually got environment variables
    if (Object.keys(envVars).length === 0) {
      return null;
    }

    return { rcDir, envVars, rawExport: rawExport.trim() };
  } catch (e) {
    // direnv may fail if the .envrc is not allowed or has errors
    // Silently skip - the agent will work without direnv
    return null;
  }
}

/**
 * Format environment variables as a key=value list for the system prompt.
 */
function formatEnvVars(envVars: Record<string, string>): string {
  const entries = Object.entries(envVars).map(([key, value]) => {
    // Truncate long values for display
    const displayValue = value.length > 100 ? value.slice(0, 100) + "..." : value;
    return `  ${key}=${displayValue}`;
  });
  return entries.join("\n");
}

/**
 * Build the system prompt injection for direnv.
 */
function buildDirenvPrompt(env: DirenvEnv): string {
  const envList = formatEnvVars(env.envVars);

  return `## Direnv Environment

The project directory (${env.rcDir}) has a direnv configuration (.envrc or .env).
The following environment variables are loaded from direnv and MUST be included in the \`env\` parameter of the \`bash\` tool for all bash commands:

${envList}

When executing bash commands, always pass these environment variables via the \`env\` parameter to ensure commands run with the correct project environment. This includes PATH modifications, virtual environment activation, database URLs, API keys, and other project-specific configuration.

For commands that need the full direnv environment, you can also use \`direnv exec ${env.rcDir} <command>\` as an alternative to passing env vars individually.`;
}

export default function direnvExtension(pi: ExtensionAPI) {
  pi.setLabel("Direnv");

  // Check if direnv is available at load time
  direnvAvailable = checkDirenvAvailable();

  pi.on("session_start", async (_event, ctx) => {
    if (!direnvAvailable) {
      return;
    }

    // Reset cache on new session
    cachedEnv = null;

    const startDir = ctx.cwd || process.cwd();
    const rcDir = findRcDir(startDir);

    if (!rcDir) {
      return;
    }

    const env = loadDirenvEnv(rcDir);
    if (env) {
      cachedEnv = env;
    }
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if (!direnvAvailable || !cachedEnv) {
      return;
    }

    // Inject system prompt with direnv environment info
    const direnvPrompt = buildDirenvPrompt(cachedEnv);

    return {
      systemPrompt: event.systemPrompt + "\n\n" + direnvPrompt,
    };
  });

  // Register a tool to query current direnv environment
  const z = pi.zod;

  pi.registerTool({
    name: "direnv_env",
    label: "Direnv Environment",
    description:
      "Show the current direnv environment variables loaded for the project directory. Returns the directory where .envrc/.env was found and all exported environment variables.",
    parameters: z.object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (!direnvAvailable) {
        return {
          content: [{ type: "text", text: "direnv is not installed or not available." }],
          isError: true,
        };
      }

      if (!cachedEnv) {
        // Try to reload
        const startDir = ctx.cwd || process.cwd();
        const rcDir = findRcDir(startDir);
        if (!rcDir) {
          return {
            content: [{ type: "text", text: "No .envrc or .env file found in current directory or parents." }],
          };
        }
        const env = loadDirenvEnv(rcDir);
        if (!env) {
          return {
            content: [
              {
                type: "text",
                text: `Found .envrc at ${rcDir}, but direnv is not allowed or failed to load. Run \`direnv allow ${rcDir}\` to grant permission.`,
              },
            ],
            isError: true,
          };
        }
        cachedEnv = env;
      }

      const lines = Object.entries(cachedEnv.envVars).map(
        ([key, value]) => `${key}=${value}`,
      );

      return {
        content: [
          {
            type: "text",
            text: `Direnv environment loaded from: ${cachedEnv.rcDir}\n\n${lines.join("\n") || "(no environment variables exported)"}`,
          },
        ],
        details: {
          rcDir: cachedEnv.rcDir,
          envVars: cachedEnv.envVars,
        },
      };
    },
  });

  // Register a tool to reload direnv environment
  pi.registerTool({
    name: "direnv_reload",
    label: "Reload Direnv Environment",
    description:
      "Reload the direnv environment from the project's .envrc/.env file. Use this after modifying the .envrc file to pick up changes.",
    parameters: z.object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, ctx) {
      if (!direnvAvailable) {
        return {
          content: [{ type: "text", text: "direnv is not installed or not available." }],
          isError: true,
        };
      }

      const startDir = ctx.cwd || process.cwd();
      const rcDir = findRcDir(startDir);

      if (!rcDir) {
        cachedEnv = null;
        return {
          content: [{ type: "text", text: "No .envrc or .env file found. Cleared cached direnv environment." }],
        };
      }

      const env = loadDirenvEnv(rcDir);
      if (env) {
        cachedEnv = env;
        const count = Object.keys(env.envVars).length;
        return {
          content: [
            {
              type: "text",
              text: `Direnv environment reloaded from ${rcDir}. ${count} environment variable(s) loaded.`,
            },
          ],
          details: { rcDir: env.rcDir, envVars: env.envVars },
        };
      } else {
        cachedEnv = null;
        return {
          content: [
            {
              type: "text",
              text: `Found .envrc at ${rcDir}, but direnv failed to load. Run \`direnv allow ${rcDir}\` to grant permission, then retry.`,
            },
          ],
          isError: true,
        };
      }
    },
  });
}
