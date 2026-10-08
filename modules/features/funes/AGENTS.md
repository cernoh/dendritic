# funes — durable agent memory

## Purpose
Dendritic integration for [huggingface/funes](https://github.com/huggingface/funes), which indexes
past AI agent sessions (pi, Claude Code, Codex, Hermes) into one local memory and serves it back to
whichever agent is running as MCP `recall` / `get` / `status` tools. Ships the pinned prebuilt
binary. Exposes `overlays.funes` (`pkgs.funes`), `packages.funes`, `apps.funes`, and
`flake.nixosModules.funes`, which puts the binary in `environment.systemPackages` alongside its two
mandatory companions, `hf` and `trufflehog`.

## Ownership
- `default.nix` — overlay, NixOS module (incl. the `trufflehog-funes` scanner shim), per-system
  package/app
- `_funes.pkg.nix` — prebuilt binary, strictly pinned (`fetchurl` + per-system SRI hash), install
  check asserting the reported version

## Local Contracts
- **`hf` (python3Packages.huggingface-hub) is part of this feature, not a separate one.** funes
  resolves its Hub token in one order: `$HF_TOKEN`, then `$HF_TOKEN_PATH`, then the stored token file
  `$XDG_CACHE_HOME/huggingface/token` (`~/.cache/huggingface/token`). The last is exactly what
  `hf auth login` writes, so the CLI is the *only* supported way to get a token into a place funes
  reads, unless the user hand-writes that file. Without `hf` on PATH, `funes add pi` prints
  "staying local — set HF_TOKEN (or run `hf auth login`) …" and there is nothing to run. Same
  `systemPackages` rationale as `funes` itself: an agent that drives `funes push` must find the same
  token the user stored.
- **The token is the user's, in `$HOME`, never in this repo.** `hf auth login` writes
  `~/.cache/huggingface/token`; funes stores agent bindings and remote state under `~/.funes/`. Both
  are outside the checkout. Nothing in this feature may materialize a token into the Nix store, a
  `home.file`, or an `environment.variables` default — a token in a store path is world-readable and
  survives in the GC root.
- **Sync itself stays a user action.** After `hf auth login`, publishing means re-running
  `funes add pi <org>/<repo>` by hand (or `funes push <org>/<repo>`); the flake never supplies the
  `<org>/<repo>` name, never creates the Hub dataset, and never calls `add` — same two reasons as
  below.
- **Binary, not source-built.** `huggingface.co/buckets/huggingface/funes/resolve/v<tag>/`, one
  asset per platform, each release tagged with `SHA256SUMS`. Building the crate instead means
  linking `lance`/`lance-index` (DataFusion + arrow 58) with `faer`, `tokenizers`, `safetensors` and
  the Xet client, and needing `vendored-openssl` for the aarch64 cross-build. Upstream ships the
  asset as its supported channel, so we fetch it.
- **The package must stay pure.** An unhashed fetch breaks the pure host eval gates, the same class
  of failure as issue #173 (`omp`).
- **Plain Rust ELF, so patchelf is safe — unlike omp.** NEEDED is exactly `libc.so.6`,
  `libm.so.6`, `libgcc_s.so.1` and the loader, max symbol version GLIBC_2.35 against upstream's 2.35
  floor. No `dontPatchELF`, no pristine-binary, no loader wrapper — just an explicit INTERP/RPATH
  rewrite in `preFixup`, verified `funes 1.6.0` under glibc 2.44.
- **The explicit `preFixup` is required; nixpkgs does not do it for you.** `fixupPhase` has no
  interpreter handling and the sole patchelf setup hook
  (`development/tools/misc/patchelf/setup-hook.sh`) only runs `patchelf --shrink-rpath`. Normally
  `--set-interpreter` happens at link time through the nix cc wrapper's `-dynamic-linker`, which
  never runs for a prebuilt binary. Omitting it leaves `/lib64/ld-linux-x86-64.so.2`, which does not
  exist on NixOS, and every exec fails with `cannot execute: required file not found`. Verified the
  hard way on the first build: the `installCheckPhase` caught it as a build failure.
- **It must be `preFixup`, not `patchPhase`.** Phase order is unpack, patch, configure, build,
  install, fixup, installCheck. `patchPhase` runs *before* install, so `$out/bin/funes` does not
  exist yet and patchelf would fail with `No such file or directory`.
- **An `installCheckPhase` on a 216 MiB ELF is cheap insurance, not waste.** A plain `nix build`
  of the very first attempt SUCCEEDED and produced a binary that linked fine and died on every
  exec, because nothing had set its interpreter. Only the version assertion turned that into a
  build failure. Keep it even when the build looks obviously correct.
- **A hook must NEVER call its own name.** `preFixup` is a hook, and stdenv already runs it via
  `runHook preFixup` inside `fixupPhase`. Writing `runHook preFixup` inside the `preFixup` body
  recurses until the stack overflows: `builder failed due to signal 11 (Segmentation fault)` at the
  top of `fixupPhase`, no diagnostic, and **no output from the body at all** — so it looks exactly
  like a segfaulting patchelf. Same trap applies to `runHook prePatch` inside `patchPhase`. Contrast
  `installPhase`, which legitimately calls `runHook preInstall`: a *phase* may invoke its pre/post
  hooks, because those are differently named; a *hook* may not invoke its own name. This cost five
  builds to find — do not reintroduce it.
- **`nativeBuildInputs = [ patchelf ]` pins a known patchelf (0.15.2)** rather than whatever stdenv
  resolves. Deliberate, not a bug fix.
- **Take the interpreter and rpath from stdenv attributes, never `$NIX_DYNAMIC_LINKER` /
  `$NIX_LDFLAGS`.** In a `mkDerivation` with no `buildInputs` both are traps: `$NIX_DYNAMIC_LINKER` is
  **empty** (it exists only inside the cc-wrapper) and `$NIX_LDFLAGS` is merely `-rpath $out/lib`. Use
  `stdenv.cc.bintools.dynamicLinker` and `lib.makeLibraryPath [ stdenv.cc.libc (lib.getLib
  stdenv.cc.cc) ]`, matching `features/omp/_omp.pkg.nix`.
- **The `installCheckPhase` is the reason this class of bug cannot ship silently.** It asserts
  `funes --version` reports `funes <pinnedVersion>`, which catches a wrong asset, a broken patchelf
  rewrite, and an unresolvable interpreter — all three link fine and die on first exec. Keep it even
  if the build seems obviously correct.
- **`funes add` is never run by the flake.** Two independent reasons, and both must keep holding:
  1. It is interactive — it asks before the first index, offers to create a Hub dataset, and refuses
     to run unattended off a terminal. An activation script would fail or silently decline for the
     user.
  2. It writes into pi's config. `~/.pi/agent` is symlinked out-of-store to
     `modules/features/pi-coding-agent/home/agent`, whose `settings.json` is **tracked in git**.
     Registering `$FUNES_BIN mcp` from outside the flake would edit a git-owned file that the next
     `home-manager` switch reverts.
- **`trufflehog` is part of this feature, not a separate one.** `funes push` will not publish
  unscanned. It resolves the scanner from `$FUNES_TRUFFLEHOG`, then `$PATH`, then Homebrew and a
  fixed dir list, and on a miss aborts with `The secret scan is mandatory - refusing to proceed
  unscanned` before writing a single chunk. Sessions are raw transcripts: a token pasted into a chat
  becomes a published chunk unless a scanner gates the push, so this is the gate, not a nicety.
  There is no in-binary fallback and no flag to skip it. Ship `pkgs.trufflehog` in the same
  `systemPackages` list as `hf`; if the attribute ever disappears from nixpkgs, vendor it the way
  `_funes.pkg.nix` vendors funes rather than dropping the gate.
- **`$FUNES_TRUFFLEHOG` must point at the shim, not at `pkgs.trufflehog`.** Two halves each pass
  `--no-update` and trufflehog's kingpin parser rejects the repeat. funes hard-codes its scanner argv
  in `src/scan.rs` (identical in v1.6.0, v1.7.0 and v1.8.0):
  `filesystem <dir> --json --no-verification --no-update --fail --fail-on-scan-errors
  --results=verified,unknown,unverified`. nixpkgs' `trufflehog` is a wrapper script that exists to
  inject its own `--no-update` (`exec -a "$0" .../.trufflehog-wrapped --no-update "$@"`, so the Go
  binary does not phone home). Result:
  `trufflehog: error: flag 'no-update' cannot be repeated, try --help`, which funes reports as
  `trufflehog exited abnormally (Some(1)); refusing to treat the text as clean`. That kills EVERY
  scan-gated operation — `funes index` as much as `funes push` — and it is a Nix packaging collision,
  never a secret in the sessions. The `trufflehog-funes` shim in `default.nix` makes the injected flag
  idempotent: it drops `--no-update` / `--no-no-update` from funes' argv and execs the real wrapper
  through `runtimeInputs`, which then injects exactly one.
  - Why a shim in `$FUNES_TRUFFLEHOG` and not a patched `pkgs.trufflehog`: funes resolves
    `$FUNES_TRUFFLEHOG` *before* `$PATH`, so it is the seam funes' own resolution order was built for.
    It needs no `overrideAttrs`, so there is no rebuilt Go derivation and no forked nixpkgs package,
    and a human typing `trufflehog` still gets the untouched wrapper. Do not "fix" this by patching
    the flag out of the scanner's argv instead — that silently re-enables the network version check
    on every scan.
  - The shim is set in `environment.variables`, not a home profile: the funes MCP server is spawned
    by whichever agent is running, which may be a system-level one.
  - **Upstream bug, not ours.** It breaks every NixOS and Guix user of `pkgs.trufflehog` who also
    passes `--no-update`, not only funes users. Drop the shim once funes stops passing the flag; until
    then, the shim is load-bearing and removing it re-breaks indexing.
- **The one-time step is the user's:** `hf auth login`, then `funes add pi`, by hand, in a real
  terminal. `funes status` then reports whether recall reads the local memory yet, and how much this
  host has yet to push. A `funes push` before both are done is expected to fail - first on the
  missing scanner (now fixed by the flake), then on the missing token (the user's `hf auth login`).
- **funes owns `~/.funes/`.** Integrations live at `~/.funes/agents/<id>/`, outside the repo, and
  funes refuses a `setup` that is group- or world-writable or not owned by the user. Do not move it
  under this checkout, and do not gitignore a path for it here.
- **Currency is a pin bump, not an activation fetch.** Unlike `omp`, there is no cheap "latest"
  indirection worth automating; a stale-but-working index beats a binary moving under a live
  integration.
- **Closure cost is real:** ~216 MiB per architecture. That is the embedding and rerank stacks, and
  it is a fetch rather than a build — but it is not a small store path.
- **Upstream publishes three assets** (`funes-x86_64-linux`, `funes-aarch64-linux`,
  `funes-arm64-apple-darwin`). `x86_64-darwin` throws on purpose; neither host is Darwin.

## Work Guidance
- Bump: read `SHA256SUMS` from the new release's `resolve/v<new>/SHA256SUMS`, convert each hex
  digest with `printf %s <hex> | xxd -r -p | base64`, bump `pinnedVersion`, confirm with
  `nix store prefetch-file --json <url>` (its `hash` field is the SRI). `pinnedVersion` and the
  `installCheckPhase` assertion must agree, so the check fails loudly on a half-finished bump.
- **Scan before push, and read the finding rather than blanket-allowing.** `trufflehog` reports
  unverified candidates by default; a chunk with a hit is a real secret to rotate, not a false
  positive to wave through with a blanket yes.
- If funes ever lands in nixpkgs, drop `_funes.pkg.nix` and the overlay and prefer the nixpkgs
  attribute; keep the NixOS module, the `hf` + `trufflehog` companions, and the no-auto-`add`
  contract.
- Adding another harness (`funes add codex`, `hermes`, `claude`) is a user action, not a flake
  change, unless a second tracked config starts being edited from outside.

## Verification
- `nix-instantiate --parse modules/features/funes/_funes.pkg.nix` and the same for `default.nix`
- `nixfmt --check` on both files with the formatter from the LOCKED nixpkgs (`nix run .#formatter` is
  broken in this flake — use `nix eval --impure --raw --expr 'let f = builtins.getFlake "<repo>";
  in f.inputs.nixpkgs.legacyPackages.x86_64-linux.nixfmt'`)
- `git add` new files BEFORE `nix eval .#…`: a flake source copy only carries tracked files, so an
  untracked `default.nix` makes the tracked `attrs/programming` import site fail with
  `undefined variable 'funes'`
- `nix eval --impure --raw .#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath`, same for
  ASAHI
- Behavioral proof that the binary landed and runs:
  `nix build --no-link --print-out-paths .#packages.x86_64-linux.funes` then
  `ls "$OUT/bin"` and `"$OUT/bin/funes" --version`
- Token chain proof (no secret printed — check existence and that funes accepts it):
  `hf auth whoami` after a login, and `nix eval --impure --raw --expr
  'let f = builtins.getFlake "git+file:///home/davr/.config/dendritic";
  in f.inputs.nixpkgs.legacyPackages.x86_64-linux.python3Packages.huggingface-hub.meta.mainProgram'`
  for the `hf` entry point. Note `builtins.getFlake "<path>"` fails on this repo: the pi
  `broker.sock` in the working tree is an unsupported flake-source file type — use `git+file://`,
  which copies only tracked files.
- Scanner-flag proof, the check that would have caught this: run funes' *own* argv through the
  evaluated shim path and require exit 0.
  `FUNES_TRUFFLEHOG=$(nix eval --impure --raw
  .#nixosConfigurations.NIXPC.config.environment.variables.FUNES_TRUFFLEHOG) funes index` — this
  realises the shim and runs the whole gate (trufflehog, then the index write). It must get past
  `scanning N chunk(s) for secrets` and finish. The failure it replaces is the exact pair of lines
  `trufflehog exited abnormally (Some(1))` + `flag 'no-update' cannot be repeated`.
  The single-flag regression is faster and needs no session data:
  `trufflehog filesystem <dir> --json --no-verification --no-update --fail --fail-on-scan-errors
  --results=verified,unknown,unverified` must exit 0 through the shim and exit 1 without it.
- Scanner proof: `nix eval --impure --raw --expr 'let f = builtins.getFlake
  "git+file:///home/davr/.config/dendritic";
  in f.inputs.nixpkgs.legacyPackages.x86_64-linux.trufflehog.meta.mainProgram'` must print
  `trufflehog` for both `x86_64-linux` and `aarch64-linux`, and `command -v trufflehog` must resolve
  after a system switch. `$FUNES_TRUFFLEHOG` must resolve to the shim, not to `pkgs.trufflehog`:
  `nix eval --impure --raw .#nixosConfigurations.NIXPC.config.environment.variables.FUNES_TRUFFLEHOG`
  must end in `-trufflehog-funes/bin/trufflehog-funes`. A real end-to-end proof is the
  `funes push` itself: it now gets past "scanning N chunk(s) for secrets" instead of erroring on the
  missing binary.

## Child DOX Index
- none — this feature is two files and no subtree
