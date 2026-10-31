# pi-bolt — Pi compiled ahead of time

## Purpose
Install [Pi-Bolt](https://github.com/opensec-git/Pi-Bolt), the `earendil-works/pi`
coding agent compiled to native code, as a second front end over the SAME
`~/.pi/agent` configuration `features/pi-coding-agent` owns.

## Ownership
- `default.nix` — flake-parts module: `flake.overlays.pi-bolt`,
  `flake.nixosModules.pi-bolt` (`environment.systemPackages`), and
  `perSystem.packages/apps.pi-bolt`.
- `_pi-bolt.pkg.nix` — the pinned prebuilt release tarball, its per-platform
  hashes, and both ELF rewrites. Its header carries the full Bun/patchelf
  evidence; read it before changing anything below.
- `modules/hosts/NIXPC/default.nix` imports this feature. **NIXPC only**, for
  the same reason `herdr-web` and `wayfinder-dashboard` are: ASAHI runs no
  coding agents, so a second agent runtime there would be dead weight. Do not
  move the import into `attrs/programming` — that bundle reaches both hosts.

## Local Contracts
- **Nothing about Pi is duplicated here.** No settings, no theme, no extension
  list: pi-bolt reads the same out-of-store-symlinked `~/.pi/agent` tree, so a
  change belongs in `features/pi-coding-agent` (or `features/scheme` for the
  theme), never in this feature.
- **The launcher name is `pi-bolt`, never `pi`.** `features/pi-coding-agent`
  already provides `pi`, and both runtimes read one config directory, so a
  second `pi` would be indistinguishable at the prompt.
- **`pi` the ELF gets PT_INTERP and nothing else.** It is a Bun standalone
  binary that maps its own file: any rpath entry (DT_RPATH or DT_RUNPATH, one
  entry or two) makes it SEGFAULT before printing a line, and running it
  through an explicit `ld.so --library-path` instead crashes with SIGBUS
  because `/proc/self/exe` is then the loader. That is why
  `bin/pi-bolt` is a `makeWrapper` launcher that prepends the Nix glibc `lib`
  to `LD_LIBRARY_PATH` (~1 ms over the bare binary). `dontPatchELF = true`
  keeps stdenv's `--shrink-rpath` off both files; the X11 native module is an
  ordinary dlopen'd shared object and DOES get a real rpath (`glibc` +
  `libxcb`).
- **The version skew is real, not cosmetic.** The pinned release embeds its own
  Pi build (`pi-bolt --version`, 1.4.0 for Pi-Bolt 1.0.3) while
  `pkgs.pi-coding-agent` is 1.3.0. Extensions in `~/.pi/agent/npm` were resolved
  against the nixpkgs Pi, and the newer embedded Pi may rewrite `settings.json`
  or a store file in a shape the older one will not read back. After a bump,
  verify with `pi-bolt list` and `pi-bolt doctor` that the shared config still
  loads, and prefer matching the versions over assuming forward compatibility.
- **`pi-bolt update` is not this feature's update path.** It installs a release
  into `~/.pi-bolt` and rewrites `~/.local/bin/pi-bolt`; neither touches the
  store copy on PATH (`pi-bolt doctor` reports the shape as "not installed (a
  build run from its folder)"). Currency is a `pinnedVersion` + hash bump in
  `_pi-bolt.pkg.nix` (recipe in that file's header), plus the variant table
  when the machine class changes.
- **Pi-Bolt does not report its own herdr state, and that is deliberate.**
  Pi-Bolt carries a built-in herdr reporter that identifies as
  `("pi-bolt","pi-bolt")`, but herdr grants pane lifecycle authority only to a
  hard-coded source/agent allowlist that this pair is not on, so a running
  Pi-Bolt pane was screen-scraped into `blocked`. `settings.json` therefore sets
  `"extensions": ["-builtin:herdr"]`, and
  `features/pi-coding-agent/home/agent/extensions/herdr-pi-bolt-state.ts` reports
  under herdr's own `("herdr:pi","pi")` identity with
  `resume_argv = ["pi-bolt","--session",…]` instead. Do not re-enable the
  builtin next to that extension: herdr keeps one hook authority per pane and
  the last report wins, so the two flap state and label. `pi-bolt doctor` naming
  the builtin as `turned off` and `herdr-agent-state.ts` as `skipped` is the
  expected shape. Details: `features/pi-coding-agent/home/agent/AGENTS.md`
  ("Herdr agent state under Pi-Bolt").
- **Variant follows the CPU, not the platform.** `x64` (the default on
  x86_64-linux) needs AVX2 and SSE4.2 and dies with "Illegal instruction"
  without them; `x64-baseline` runs anywhere with SSE4.2; `arm64` covers
  ASAHI. It is a callPackage argument, not a NixOS option, because the default
  is right for both hosts — a host without AVX2 overrides it where the package
  is called.

## Work Guidance
- Bump: take the new release's `SHA256SUMS`, convert the variant's sha256 with
  `nix hash convert --hash-algo sha256 --to sri <hex>`, replace the hash and
  `pinnedVersion` together.
- Never "clean up" the wrapper into a plain symlink, and never add
  `autoPatchelfHook`: both reintroduce the segfault described above.
- The package is ~250 MiB of closure (one executable). That is upstream's
  shape, not packaging slack; it is a fetch, so it costs store space, not build
  time.

## Verification
- `nix-instantiate --parse modules/features/pi-bolt/default.nix`
- `nix build --no-link .#pi-bolt` — builds the derivation, and the
  `installCheckPhase` runs `pi-bolt --version` and resolves the X11 module's
  `libxcb` through `ldd`.
- `nix eval --impure .#nixosConfigurations.NIXPC.config.environment.systemPackages --apply 'ps: builtins.length (builtins.filter (p: (p.pname or "") == "pi-bolt") ps)'`
- Runtime, against the shared config: `pi-bolt --version`, `pi-bolt list`,
  `pi-bolt doctor` (the last names every extension it loads or skips, so it is
  the fastest way to see the shared tree working).
- Herdr reporting: `node
  ~/.pi/agent/extensions/herdr-pi-bolt-state.check.mjs`, then inside a herdr pane
  `herdr agent list` must show the Pi-Bolt pane as agent `pi` with
  `screen_detection_skipped: true`, and `herdr pane get <pane>` must carry an
  `agent_session` from `herdr:pi`. `~/.config/herdr/session.json` keeps the
  matching `agent_resume.argv` (`pi-bolt --session …`).

## Child DOX Index
- none
