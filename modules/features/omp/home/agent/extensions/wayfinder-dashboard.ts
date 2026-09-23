/**
 * wayfinder-dashboard tool — register the current map and record grill data.
 *
 * Thin wrapper over `lib/dashboard.ts` for manual use. The automatic path
 * needs no tool call: `grill_form` records each round it serves and each
 * submit it stores, and `wayfinder_view` ensures the current map first.
 */
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { ensureMap } from "./lib/dashboard";

export default function wayfinderDashboardExtension(pi: ExtensionAPI) {
  const z = pi.zod;

  pi.setLabel("Wayfinder Dashboard");

  pi.registerTool({
    name: "wayfinder_dashboard",
    label: "Wayfinder Dashboard",
    description:
      "Check whether a wayfinder map is listed on the local dashboard (NIXPC :8787), and register it when it is not. " +
      "Call it with the repo and map number before grilling, so the dashboard shows every round since the last boot.",
    parameters: z.object({
      action: z.enum(["ensure"]).describe("Only action: ensure the map is listed."),
      repo: z.string().describe("Repository holding the map, as `owner/name`."),
      map: z.number().int().positive().describe("Map issue number."),
      title: z.string().optional().describe("Map title, stored when the map is first registered."),
    }),
    loadMode: "essential",
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const repo = params.repo.trim();
      const result = ensureMap(repo, params.map, params.title?.trim() || `#${params.map}`);
      if ("error" in result) {
        return { content: [{ type: "text", text: `Dashboard unreachable (${result.error}). GitHub stays the map.` }] };
      }
      return { content: [{ type: "text", text: `Map listed on the dashboard as ${result.id}.` }], details: result };
    },
  });
}
