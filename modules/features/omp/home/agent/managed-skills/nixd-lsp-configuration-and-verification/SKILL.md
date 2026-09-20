---
name: nixd-lsp-configuration-and-verification
description: "Wire and verify nixd's LSP configuration in an nvf/NixOS flake: option providers from evaluated hosts, semantic tokens, and the measurement recipes. Use when asked to add flake inputs/options to nixd, turn on nixd semantic tokens, or prove a nixd config change without rebuilding the system."
---

# nixd LSP configuration and verification

Applies to nixd 2.9.x (store and `main`) configured through nvf's `vim.lsp.servers.nixd`, i.e. `modules/features/nvf/_nixd.nix` + `default.nix` in this flake.

## nixd's config surface is four keys

`lib/Controller/Configuration.cpp:40-48` parses only `formatting`, `options`, `nixpkgs`, `diagnostic`. `ObjectMapper::mapOptional` silently drops anything else, so an invented `inputs` / `flake.inputs` / `semanticTokens` key is a no-op that looks wired. Verify by reading the source, not the docs page alone.

## What cannot work

- **`inputs.<TAB>` completion is impossible.** Select completion runs the idiom gate first: `varSelector` = `getKnownIdiomSelector(IdiomSet.find(name))` with `IdiomSet = {pkgs, lib}` (`lib/Controller/AST.cpp:142`), and log line `completion/select: skipped, reason: not an idiom`. No config key reaches it; nixd issue #567 is open. Reaching input *names* at all needs the merge hack `nixpkgs.expr = (import f.inputs.nixpkgs {}) // { inputs = f.inputs; }` → `pkgs.inputs.<name>`, which pollutes `pkgs.` completion.
- **`...options.home-manager.users.type.getSubOptions []` is partial.** `home-manager.users` is `attrsOf hmModule`, `hmModule = submoduleWith { modules = base ++ cfg.sharedModules }`; a user's own `imports` are instance-level, so nvf/omp/stylix options are absent (measured: `programs.nvf` false). Only a move to `home-manager.sharedModules` changes that.

## Wiring recipes

- **Option providers:** `options.<name>.expr`; names are labels only, all entries are merged in every completion list. Use **one host-selected provider**, never one per host (duplicates in every list).
- **Host selection:** the HM module cannot see the flake attribute name. Branch on `pkgs.stdenv.hostPlatform.isAarch64` (the split already used for the flutter-tools gate) or add `dendritic.hostName` next to `dendritic.userName` in `system/core/user.nix`. Evaluate the correct HM user name too (`da` on ASAHI, not `davr`) — a wrong one fails with `does not provide attribute … (Did you mean da?)`.
- **Full HM tree:** export it from inside the user submodule: declare `options.dendritic.nixdOptionTree = lib.mkOption { type = lib.types.raw; internal = true; }` and set `config.dendritic.nixdOptionTree = options;`. Gotcha: a module cannot mix top-level `options`, `config`, and plain config attrs — move `home = {…}` into an explicit `config` attr. Verified: export has `programs.nvf`, `programs.omp`, `stylix`.
- **flake-parts paths** need `debug = true` in a flake-parts module (this flake: `modules/parts.nix`) before `debug.options` / `currentSystem.options` exist.
- **Semantic tokens** are a CLI flag only: `--semantic-tokens=true` (or `NIXD_FLAGS`). Two routes past nvf's preset, which already sets `cmd` (type `uniq (listOf str)` — a second plain definition hard-throws "expected to be unique"):
  1. `cmd = lib.mkForce [ "${pkgs.nixd}/bin/nixd" "--semantic-tokens=true" ];` (priorities resolve before the type merge); needs `pkgs`+`lib` in scope, so pass them into `_nixd.nix` or set it in `default.nix`.
  2. `vim.lsp.servers.nixd.cmd_env = { NIXD_FLAGS = "--semantic-tokens=true"; };` — no mkForce, no `pkgs` needed; `lspOptions.freeformType = attrsOf anything` forwards it to `vim.lsp.config`.
  Client side needs nothing: `vim/lsp/client.lua:537-541` eagerly requires `vim.lsp.semantic_tokens`, whose last statement is `M.enable(true)` → global marker on → `is_enabled` true for buffers. The `_capability` comment about buffers defaulting to disabled only holds with no global marker set (touching the lazy module is what sets it).

## Verification (no system rebuild)

1. Parse + format with the **locked** nixfmt: `nixfmt --check <file>` using `pkgs.nixfmt` from the flake's nixpkgs (1.5.0 here), or let the gate judge: the `fmt` gate runs `nixfmt --check` over every `*.nix` (`modules/verify.nix`).
2. Generated config: `nix eval --impure --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<USER>.programs.nvf.settings.mnw.initLua`, and the provider object as JSON: `nix eval --impure --json .#…programs.nvf.settings.vim.lsp.servers.nixd.settings.nixd` — feed that JSON straight to nixd as its config.
3. Confirm the expressions themselves: `nix eval --impure .#nixosConfigurations.<HOST>.options --apply 'o: { n = builtins.length (builtins.attrNames o); hasStylix = o ? stylix; }'`, and the HM export similarly.
4. Drive nixd over stdio with a small harness: LSP `Content-Length` framing, `capabilities.workspace.configuration = true`, answer `workspace/configuration` with `[configObj]` (the first array element **is** the `nixd` object, `Configuration.cpp:91-124`), then `textDocument/didOpen` + `textDocument/completion`. Working probes (positions on line 2): `boot.loa`, `programs.nvf.en`, `flake.nixo` → expect `["loader"]`, `enable…`, `["nixosConfigurations","nixosModules"]`.
5. Configured editor: build `.#nixosConfigurations.<HOST>.config.home-manager.users.<USER>.programs.nvf.finalPackage` (~15 s warm) and run `--headless <file> -c 'luafile check.lua'`; check `client.config.cmd`, `server_capabilities.semanticTokensProvider`, and extmark count in namespace `nvim.lsp.semantic_tokens:<client_id>`.

## Traps

- **`builtins.getFlake (toString ./.)` is a path flake** and copies the whole worktree, so any stray `.nix` under `modules/` breaks eval: omp session caches (`modules/features/omp/home/agent/sessions/**/url-search/*.nix`) hit `import-tree` as flake-parts modules → `function 'anonymous lambda' called with unexpected argument 'self'`. `.#` evals keep working (git tree), which hides the problem. Harden with `builtins.getFlake ("git+file://" + toString ./.)`, keep the agent caches out of `modules/`, or verify in a clean copy: `git archive HEAD | tar -x -C /tmp/x` plus the modified files.
- Option providers are evaluated by nixd at startup: tens of seconds and hundreds of MB for a real host. State the cost.
- Provider eval failures only log (`option worker reported: -32001: attrname X not found in attrset`) — each provider is asked for every scope, so expect noise from the non-matching ones.
- `_nixd.nix` is imported as a bare attrset at flake scope: no `pkgs`, `lib`, or `inputs` in scope. Take them as function arguments when needed.
- `root_markers` in `_nixd.nix` is redundant with nvf's nix preset (`["flake.nix"]`) and the preset (`[".git"]`) — the generated list repeats entries.
