/**
 * wayfinder-dashboard feed — the `wayfinder_dashboard` tool.
 *
 * Purpose: feed the wayfinder-dashboard container (NIXPC, loopback :8787)
 * from an omp session. Omp checks whether the current map is already listed,
 * and registers it when it is not. Grill rounds and answers reach the
 * dashboard through explicit `record` / `answer` actions, so the dashboard
 * shows every round since the last boot without touching the grill_form or
 * wayfinder_view loops.
 *
 * Contract:
 * - The dashboard is best-effort. Every action catches its own failure and
 *   reports `dashboard: unreachable` in text; it never throws into the
 *   calling flow.
 * - GitHub stays the source of truth for maps and tickets. The dashboard
 *   holds a registry copy (repo, number, title) plus recorded rounds and
 *   answers only.
 * - `grill-form.ts` calls `recordRound` after it serves a round page and
 *   `recordAnswers` after it stores a submit; this tool's `record` and
 *   `answer` actions are the manual path to the same endpoints.
 */
import { spawnSync } from "node:child_process";

const DASHBOARD = "http://127.0.0.1:8787";

export interface DashboardQuestion {
  id: string;
  title: string;
  body?: string;
  recommendation?: string;
  choices?: string[];
}

/** Register the map when missing, no-op (returns it) when listed. */
export function ensureMap(repo: string, number: number, title: string): { id: string } | { error: string } {
  try {
    const listed = JSON.parse(post("/api/maps", { repo, number, title }, "GET")) as { id: string }[];
    const hit = listed.find((entry) => entry.id === `${repo}#${number}`);
    if (hit) return { id: hit.id };
  } catch {
    // Fall through to the idempotent register call below.
  }
  try {
    const created = JSON.parse(post("/api/maps", { repo, number, title }, "POST")) as { id: string };
    return { id: created.id };
  } catch (error) {
    return { error: error instanceof Error ? error.message : String(error) };
  }
}

/** Record one grill round (questions + live form URL) under a map id. */
export function recordRound(
  mapId: string,
  round: { number: number; title: string; intro?: string; questions: DashboardQuestion[]; formUrl: string },
): string | undefined {
  try {
    post(`/api/maps/${encodeURIComponent(mapId)}/rounds`, round, "POST");
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}

/** Record one submitted answer set under a map id. */
export function recordAnswers(
  mapId: string,
  answers: { round: number; answers: { id: string; title: string; answer: string }[]; extra?: string },
): string | undefined {
  try {
    post(`/api/maps/${encodeURIComponent(mapId)}/answers`, answers, "POST");
    return undefined;
  } catch (error) {
    return error instanceof Error ? error.message : String(error);
  }
}

function post(path: string, value: unknown, method: string): string {
  const args = ["-sS", "-m", "5", "-X", method, "-H", "content-type: application/json"];
  if (method === "POST") args.push("-d", JSON.stringify(value));
  args.push(`${DASHBOARD}${path}`);
  const result = spawnSync("curl", args, { encoding: "utf8", timeout: 8000 });
  if (result.error) throw new Error(`dashboard unreachable: ${result.error.message}`);
  if (result.status !== 0) throw new Error(`dashboard unreachable: ${(result.stderr || "curl failed").trim()}`);
  return result.stdout;
}
