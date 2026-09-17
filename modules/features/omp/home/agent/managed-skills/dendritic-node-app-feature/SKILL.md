---
name: dendritic-node-app-feature
description: "Package a Node/npm app (or herdr plugin) as a dendritic flake feature: buildNpmPackage hook facts, native optional addons, fetchzip vs tarball hashes, and the home-manager systemd user-unit traps (Environment is listOf str, user units never see /run/current-system/sw/bin)."
---

Apply when adding a feature under `modules/features/<name>/` that runs a
Node/npm program (web bridge, CLI, plugin). Verified against cernoh/dendritic
while adding `herdr-web` (PR #202), 2026-09.

## Hashes: two different kinds

- `fetchFromGitHub.hash` is the **fetchzip-normalized** hash, not the codeload
  tarball hash. `nix hash file --sri src.tar.gz` gives the wrong value and the
  build fails with a hash mismatch. Use:
  `nix run nixpkgs#nix-prefetch-github -- <owner> <repo> --rev <rev>`.
- `npmDepsHash` comes from the lockfile, not from the source:
  `nix run nixpkgs#prefetch-npm-deps -- package-lock.json`. Pin the rev, never a
  branch, and confirm the repo's default branch first (`master` is common).

## buildNpmPackage internals that decide the derivation

Read the hooks in the store before guessing: `npm-config-hook`,
`npm-build-hook`, `npm-install-hook` under
`/nix/store/*-npm-*-hook/nix-support/setup-hook`.

- `npmConfigHook` (postPatch) already exports `npm_config_nodedir` from the
  store nodejs and runs `npm ci --ignore-scripts` **and then `npm rebuild`**.
  Native addons therefore compile offline. Do not add `--nodedir=` to
  `npmFlags`; it only produces `npm warn Unknown cli config`.
- `npmBuildHook` requires a `build` script. A package without one fails with
  `npm error Missing script: "build"`. Set `dontNpmBuild = true`; that skips
  only `npm run build`, not the `npm rebuild` in the configure phase.
- `npmInstallHook` copies the `npm pack` file list into
  `$out/lib/node_modules/<name>` and copies a pruned `node_modules`. It creates
  a `$out/bin` entry only if `package.json` has a `bin` field.
- No `bin` field, or a `main` that needs `__dirname` (static assets, `lib/*`
  resolved relatively) → add a launcher in `postInstall`:
  `makeWrapper ${lib.getExe nodejs} $out/bin/<name> --add-flags $out/lib/node_modules/<name>/server.js`.
- An **optional** dependency that fails to compile does not fail `npm ci`.
  Keep it (it is usually the feature) and prove it with a check:
  `doInstallCheck = true; installCheckPhase = ''cd $out/lib/node_modules/<name>; ${lib.getExe nodejs} -e 'require("<addon>")' ''`.
  Do not start the server in a build sandbox when startup spawns a daemon.

## Run-time binaries and PATH

Find every `execFile`/`spawn` in the app and give the service those binaries:
`grep` the source for `spawn(`, `execFile(`, `exec(`. Common ones are the app
under test, `zoxide`, `find`, `ss`, `git`.

A `systemd.user.services.<name>` unit does **not** inherit
`/run/current-system/sw/bin`. systemd uses its compiled-in default PATH. List
the binaries explicitly:
`Service.Environment = [ "PATH=${lib.makeBinPath [ … ]}" ]`.

Do not bake a self-updating tool (e.g. `herdr`, which has `herdr update`) into
the package wrapper; a store copy can lag the running daemon. Put it on the
service PATH instead.

## home-manager systemd unit traps

- `Service.Environment` is `listOf str` in home-manager (NixOS's `path` option
  is not the same). An **attrset** fails with
  `not of type (list of string)`. Write `[ "K=V" "K2=V2" ]`.
- `Service.Path` is not a unit option (that is a `[Path]` unit). Use the PATH
  environment variable.
- `Install.WantedBy = [ "default.target" ]` produces both
  `~/.config/systemd/user/<name>.service` and the
  `default.target.wants/<name>.service` symlink. Verify with:
  `nix eval --impure --json .#nixosConfigurations.<HOST>.config.home-manager.users.<user>.home.file --apply 'builtins.attrNames'`
  (pipe through a file, not stdin: `nu -c 'open x.json | …'`).
- The unit text is a `writeTextFile`; get the store path, then realise it with
  `nix-store --realise <drvPath>` and read the file to check the rendered
  `[Service]` block.

## Upstream plugin manifests are not a packaging plan

A herdr plugin manifest (`herdr-plugin.toml` with `[[build]] command = ["npm",
"install"]` and a `[[startup]]` hook) installs at run time from a checkout: it
needs the network and pins nothing. Build the thing in Nix and run it under a
service instead. Record that decision in the module header, since the plugin
route looks tempting.

## Verify

- `nix build --impure --no-link --print-out-paths --expr` with
  `pkgs.callPackage ./_<name>.pkg.nix { }` builds the package alone, before
  host wiring; get `pkgs` from the worktree flake, never the dirty main
  checkout (`builtins.getFlake "<worktree-path>"`).
- `git add` new files: an unrelated agent's broken tree in the main checkout
  can also make `getFlake` on the main path fail mid-flight.
- Then: `nix-instantiate --parse`, `nixfmt` from the locked nixpkgs,
  `nix eval --accept-flake-config --raw .#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath`
  (pure — this is CI's purity gate), and `nix flake check --impure`.
- Run the service for real before claiming it works:
  `systemd-run --user --unit=<name> --setenv=PATH="<the unit PATH>" … <wrapper>`,
  then curl the app, read `journalctl --user -u <name>`, and stop it. This is
  the only test that proves the PATH list and the environment are right.
