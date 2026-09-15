/**
 * The HTML environment: one temp folder per session.
 *
 * Purpose: give the generated pages a home that holds their data, so the
 * session can inspect the rounds and the answers after the fact, and so a page
 * that needs a framework can be built there.
 *
 * Layout:
 * - `data/round-<n>.json` — the questions of one round, as served.
 * - `data/answers-<n>.json` — the answers the user submitted.
 * - `public/round-<n>.html`, `public/done.html` — the pages the tools serve.
 * - `public/<anything>` — a framework build drops its output here, and the
 *   server serves it on `/g/<token>/env/<path>`.
 * - `flake.nix` — a dev shell with Node and Bun, for a framework build.
 *
 * Contract:
 * - The folder lives under the system temp dir and is never part of a repo.
 * - One folder per omp process, created on first use.
 * - The folder holds no secrets. The loopback server token is not written here.
 */
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export interface HtmlEnv {
  dir: string;
  dataDir: string;
  publicDir: string;
}

let cached: HtmlEnv | undefined;

const ENV_FLAKE = `{
  description = "omp HTML environment: a dev shell for framework builds of the served pages.";

  inputs.nixpkgs.url = "nixpkgs";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
    in
    {
      devShells = nixpkgs.lib.genAttrs systems (system: {
        default = nixpkgs.legacyPackages.\${system}.mkShell {
          packages = [
            nixpkgs.legacyPackages.\${system}.nodejs_22
            nixpkgs.legacyPackages.\${system}.bun
          ];
        };
      });
    };
}
`;

const ENV_README = `# omp HTML environment

One temp folder per omp session. The HTML tools serve the pages from here and
write their data here.

## Layout

- \`data/round-<n>.json\` questions of one round, as served
- \`data/answers-<n>.json\` the answers the user submitted
- \`public/round-<n>.html\` the form page of one round
- \`public/done.html\` the celebration page
- \`public/\` every other file is served on \`<base>/env/<path>\`
- \`flake.nix\` dev shell with Node and Bun

## Build a page with a framework

Run every step inside the dev shell, and write the output into \`public/\`:

    nix develop . -c bun install
    nix develop . -c bun run build

Then open \`<base>/env/<file>\`, where \`<base>\` is the URL the tool printed.

## Copy the answers out

The submitted answers stay in \`data/\`. They are also injected into the omp
session as a user message, so the session holds its own copy.
`;

/** Create or reuse this process's HTML environment folder. */
export function htmlEnv(): HtmlEnv {
  if (cached) return cached;
  const dir = mkdtempSync(join(tmpdir(), "omp-html-env-"));
  const dataDir = join(dir, "data");
  const publicDir = join(dir, "public");
  mkdirSync(dataDir, { recursive: true });
  mkdirSync(publicDir, { recursive: true });
  writeFileSync(join(dir, "flake.nix"), ENV_FLAKE, "utf8");
  writeFileSync(join(dir, "README.md"), ENV_README, "utf8");
  cached = { dir, dataDir, publicDir };
  return cached;
}
