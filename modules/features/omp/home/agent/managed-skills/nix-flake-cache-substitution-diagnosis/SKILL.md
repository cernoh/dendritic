---
name: nix-flake-cache-substitution-diagnosis
description: "Diagnose and fix flake inputs whose packages never substitute from an upstream Cachix cache (404 narinfo): the follows trap, per-(rev, nixpkgs) cache identity, the cachix-branch pin, and the narinfo/dry-run proof recipe"
---

## When to use
A flake input's package builds from source even though the substituter is configured and upstream publishes a cache. Also when adding an input whose upstream ships prebuilt binaries.

## Cache identity rule
A Cachix cache stores **store paths**, not derivations. A path is reproducible only for the exact input graph upstream built. So the cache serves a pair:

`(input rev) × (nixpkgs rev the input's own flake.lock pins)`

Any other nixpkgs rev — including your repo's — yields a different path and a 404.

Two corollaries:
- `inputs.<input>.follows = "nixpkgs"` on a cache-published input means permanent cache misses. Upstream's docs usually say this explicitly ("omit `inputs.nixpkgs.follows`").
- Tracking an input's HEAD is unsafe: CI may not have built that commit yet. Pin the upstream cache branch when one exists (`github:noctalia-dev/noctalia/cachix` — always the newest already-cached commit).

## Diagnosis (no builds)
1. Get the derivation/out paths your flake produces, both systems:
   `nix eval --impure --raw '.#nixosConfigurations.<HOST>.config.<option>.outPath'`
2. Probe the cache for each path (no narinfo tooling needed):
   `curl -sS -o /dev/null -w '%{http_code}\n' -I "https://<cache>.cachix.org/<32-char-hash>.narinfo"`
   `200` cached, `404` miss.
3. Confirm the cache does serve the upstream graph: evaluate straight from upstream (uses *its* flake.lock):
   `nix eval --raw 'github:<owner>/<repo>/<rev>#packages.<system>.default.outPath'` then re-probe.
4. Decide with `nix build --dry-run`: `this derivation will be built` (miss) vs `these N paths will be fetched` (hit). Absolute paths: already-realized paths print nothing.

## Fix
1. Drop `inputs.<input>.follows = "nixpkgs"`. Safe when only the *package* crosses the boundary — nixpkgs modules take `pkgs` from the host eval, so no module-system mixing. Cost: a second nixpkgs instantiation for those packages.
2. Pin a cache branch if upstream has one; otherwise keep the default branch and accept a possible local build right after a bump.
3. **Re-lock with care.** `nix flake lock` on a *changed* input spec re-resolves its sub-inputs to the channel/tarball **latest**, not to the input's own flake.lock. That is still a miss. Verified behaviour:
   - fresh add with a rev-pinned parent URL → inherits upstream's locked sub-inputs;
   - fresh add with an unpinned parent URL, or any edit that changes the input spec → re-resolves sub-inputs to latest.
   Check the resulting rev and, if needed, set `.nodes.<input>.locked.{rev,narHash,lastModified}` by hand (nix validates the narHash) so it matches upstream's lock, then re-verify with the narinfo probe.
4. Re-lock after rebasing onto a moved base: a rebase can silently keep the old locked rev when only the URL/ref changed. Re-check the rev.

## Verification bar
- narinfo 200 for every package × every system.
- Real build, not just dry-run: `copying path ... from 'https://<cache>.cachix.org'`.
- Host toplevel eval per host, then the repo's whole-flake gate (`nix flake check --impure`).

## Pitfalls
- Don't reason "the substituter is listed in `nix config show`, so substitution works" — configured cache ≠ reachable paths.
- `--dry-run` output must be filtered for the build/fetch summary lines; a tail-only view shows dependency fetches and hides `will be built`.
- GitHub Actions run objects can appear 10+ minutes after a push; zero runs is usually latency, not a repo misconfiguration.
- Commit-time artifacts: running repo scripts with `nix shell nixpkgs#python3` creates `__pycache__/`; unstage before committing.
