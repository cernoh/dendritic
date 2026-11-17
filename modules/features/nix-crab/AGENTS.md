# nix-crab — Steam client unlock stack (NIXPC only)

## Purpose
Declarative h3adcr-b equivalent for Steam: SLSsteam injection (upstream or the
slsteam-moon fork), CloudRedirect cloud saves, the optional Millennium framework
with store-installed plugins/themes, the ACCELA and SteaMidra app wrappers, the
LuaTools stack (Lumen + plugin), and the client-downgrade tool. Exposes
`flake.nixosModules.nix-crab` and `flake.homeManagerModules.nix-crab`; the NixOS
half injects the home-manager half through `home-manager.sharedModules`, so one
host import is the whole enable switch. NIXPC only — ASAHI runs no Steam, which is
why `modules/hosts/NIXPC/default.nix` lists it and ASAHI never does.

## Ownership
- `default.nix` — flake-parts wiring and the enable switches this feature is built
  around (slssteam, cloudredirect, downgrade, accela, steamidra on; millennium,
  slssteam-moon, moon hook, luatools off).
- `_slssteam.nix` — the injection: fork choice, slsteam-moon source build, the
  rpath-stripped audit staging, `programs.steam` override.
- `_cloudredirect.nix` — `LD_PRELOAD` hook choice + `services.flatpak.enable`.
- `_millennium.nix` — the `pkgs.steam` overlay (gated, off).
- `_downgrade.nix` — `nix-crab-downgrade` and its four pinned upstream artifacts.
- `_home.nix` — `services.sls-steam.config` defaults, the CloudRedirect Flatpak app
  and remotes, netsock, the two `~/.local/share` links the app checks.
- `_status.nix` — `nix-crab-status` (text + `--json`) and `nix-crab-update`.
- `_addons.nix` — Millennium plugins/themes, stamp-managed at activation.
- `_luatools.nix` — Lumen + LuaTools plugin under `~/.local/share/Lumen`.
- `_steamidra.nix`, `_accela.nix` — the two AppImage apps.
- `_lib.nix` — shared `hookFile` / `hookStaged` helpers.
- `steam.cfg` — the two-line update-blocking file the downgrade installs.
- Upstream owns everything inside `inputs.nix-crab`'s inputs (`sls-steam`,
  `slsteam-moon`, `millennium`, `lumen`, `luatools-moon`, `cloudredirect*`,
  `steamnetsock`, `accela`, `steamidra`).

## Local Contracts
- **The implementation is ours; the `nix-crab` input is a pin carrier.** No file
  is imported from `inputs.nix-crab` any more — every artifact comes from
  `inputs.nix-crab.inputs.<name>`, and the modules in this directory are this
  repo's own source. That removes the upstream eval bugs the old file-by-file
  import existed to dodge (unbound `pkgs` in upstream's `cloudredirect.nix`, the
  `type = "file"` input treated as a directory) and means an upstream refactor can
  no longer break an eval here. **Bump contract:** a `nix flake update` of
  `nix-crab` still moves every pin at once, so read upstream's `flake.nix` for added
  or removed inputs, and re-check the four rotating downgrade FODs below and the
  Millennium hash.
- **`_`-prefixed files are the rule.** `import-tree` skips any path containing
  `/_`, and every file here except `default.nix` is a NixOS or home-manager module
  that would break the flake if it were registered as a flake-parts module. Adding
  a module means: `_name.nix`, an `import` in `default.nix` (passing the inputs it
  needs as arguments — modules never read `inputs` themselves), and `git add -N`
  so the flake source can see it.
- **Option names are upstream's on purpose.** `programs.nix-crab.{slssteam,
  slssteam-moon,cloudredirect,millennium,downgrade,accela,steamidra,luatools}` keep
  the upstream surface, so the README and any user config still apply; only the
  implementation differs.
- **`slssteam-moon.enable` takes precedence over `slssteam.enable`.** Both forks
  produce the same two objects (`SLSsteam.so` + `library-inject.so`), so the switch
  is one store path, and everything downstream stays fork-agnostic. The moon fork
  ships no flake: it is built here with the 32-bit toolchain upstream uses, with
  only the two Steam-loaded objects as make targets.
- **The staging derivation is named after the fork, and that name is the runtime
  contract.** `SLSsteam-audit-upstream` / `SLSsteam-audit-moon` is what
  `nix-crab-status` matches out of the live `LD_AUDIT` in `/proc`. A fork-blind name
  makes the `Fork:` line always read `none` while Steam is running.
- **The audit objects must have no RUNPATH.** They are built against their own
  32-bit glibc; Steam's FHS environment already has one loaded, and the loader
  honours the RUNPATH, so a second libc ends up in the same process and every
  32-bit program dies with "stack smashing detected". `patchelf --remove-rpath` on
  both objects is the fix; the direct `NEEDED` (openssl, curl) stay reachable.
- **`--ro-bind /sys /sys` is required.** Steam's bubblewrap namespace has no
  `/sys`, so Mesa cannot resolve `/sys/dev/char/226:*` or `/sys/class/drm`, drops to
  llvmpipe, and 32-bit vgui2 fatal-asserts on `glXChooseVisual failed`.
- **`LD_PRELOAD` reaches Steam only through `programs.nix-crab.slssteam.extraEnv`.**
  `programs.steam.extraEnv` is not an option; it is an argument to
  `pkgs.steam.override`, which the injection module owns. That is also why a
  CloudRedirect hook without an injection gets a `warnings` entry instead of
  silently doing nothing.
- **One CloudRedirect hook, one store path.** `_lib.hookFile` accepts both input
  shapes (`type = "file"` inputs *are* the `.so`; the moon forks are checkouts with
  it at the root), and `_lib.hookStaged` copies it to a derivation named
  `cloud_redirect.so`. The NixOS half puts that path in `LD_PRELOAD` and the home
  half links `~/.local/share/CloudRedirect/cloud_redirect.so` at the identical
  derivation, which dedupes — so `nix-crab-status` can identify the wired hook by
  exact path instead of by filename guessing. Do not "simplify" one side to read
  the raw input: the app's deploy check and Steam's loader would then disagree.
- **The flatpak remote list is declared whole, and the mirror is not optional.**
  Upstream's remote points at `Selectively11`'s gh-pages branch, which is gone; a
  failing `flatpak remote-add` makes `flatpak-managed-install` exit 1 and
  `switch-to-configuration` abort with status 4, on every activation. The live
  continuation is `crghofficial/cloudredirect` (same C++ sources, same
  `org.cloudredirect.CloudRedirect` app id; its `cloud_redirect_cli` narHash is
  byte-identical to the asset nix-crab had locked from the dead URL). Both
  `cloudredirect` and `cloudredirect-cli` are `type = "file"` inputs pinned by
  narHash at a **versioned** asset URL, and `nix-crab.inputs.cloudredirect{,-cli}`
  follow ours.
- **The home half imports this repo's `nix-flatpak`, never nix-crab's copy.** Two
  copies would declare `services.flatpak` twice and abort the eval.
- **Millennium is off at the pinned rev: its Bun-deps FOD hash is stale.** At
  3.4.0-beta.7 `millennium-typescript-bun-deps` declares
  `sha256-BEupNhAlkAELGGLj6/SVUjj101hBm4JzJH9N5i1qM6A=` but `bun install
  --frozen-lockfile` now produces
  `sha256-QFY5nzgCcvurpHkLapChs1A7ce+FnKwY92rkskUADFc=` (verified 2026-11-17), so
  every rebuild dies with `hash mismatch in fixed-output derivation` before Steam
  is reached. That hash is upstream's, not ours — never hand-edit it. The option is
  `lib.mkIf`-gated and the overlay is lazy, so with it off `programs.steam.package`
  is plain nixpkgs Steam and the injection module's override is the base.
  **Re-enable contract:** bump the `millennium` input to a revision whose
  `outputHash` is current, flip the switch, and confirm
  `millennium-typescript-bun-deps` realizes; `nix-crab-status`-visible theming comes
  from the addon lists, not from this switch.
- **Millennium + LuaTools are mutually exclusive.** Millennium launches
  `steamwebhelper` with `--remote-debugging-pipe`, so no TCP port exists,
  `~/.local/share/Lumen/cef_port` is never written and Lumen cannot attach. Two
  warnings cover the combinations that cannot work; do not turn them into
  automatic switching.
- **The downgrade's four upstream artifacts are mutable `refs/heads` URLs, so they
  rot.** `_downgrade.nix` pins the client manifest (`SteamTracking`, branch
  `headcrab`), `dgsc`, `dlm` and `sources.txt` (`h3adcr-b-modul3s`, `main`) by
  content hash. Upstream rotates them every few weeks and each rotation turns every
  downstream build into `hash mismatch in fixed-output derivation`, on any
  `nixos-rebuild`, whether or not the downgrade is ever run. This hash **is** ours
  to bump: re-pin all four together (one stale pin hides the next), after checking
  the body is the real artifact — a 404 or redirect page hashes just as cleanly.
- **`slssteam.manageConfig` defaults to `false`.** `config.yaml` is left unmanaged
  so SteaMidra can append its own key block; the typed
  `services.sls-steam.config` option is still evaluated, and
  `xdg.configFile."SLSsteam/config.yaml".enable` is what decides whether it is
  written. Extra freeform keys (`LogLevels`, `CDKeys`, `MaxSchemaTries`, …) are
  supplied because the typed module lags SLSsteam's C++ and SLSsteam notifies
  "Missing …" for each absent key on every start.
- **SLSsteam's YAML is last-occurrence-wins.** Both `nix-crab-status` and
  CloudRedirect's own parser accept `no`/`false` and `yes`/`true`, and both take the
  last value — which is why SteaMidra's appended block is dangerous and why the
  status tool prints the last occurrence and warns about duplicates.
- **Seeded, never managed: ACCELA's `ACCELA.conf`.** QSettings rewrites it, so a
  store symlink breaks it; the activation installs it only when absent. SteaMidra's
  AppImage is the same story at a larger scale — the launcher downloads the locked
  version into `~/.local/share/SteaMidra` on first run, because SFF publishes no
  versionless asset URL and `sff/core/utils.py` writes `settings.bin` next to the
  binary.
- **Both apps own their `~/.local/share/applications` entry with `force`.** Both
  write a broken one on startup (raw AppImage `Exec`, wrong `Icon`), and
  `XDG_DATA_HOME` is searched before the profile.
- **LuaTools copies its two dists out of the store and stamps them.** Lumen and the
  plugin write at runtime (config, manifest packs, `cef_port`, plugin state), so a
  store symlink is impossible; the stamp holds the store path of the previous dist
  so only that dist's files are removed on a bump, keeping the runtime state.
- **The `lumen` launcher is a derivation, not a heredoc.** It must `cd` into the
  install dir (`lumen.bin` resolves `lua/` relative to the cwd), and it unsets
  `LD_AUDIT`/`LD_PRELOAD` **inside** `steam-run`: those carry slsteam-moon's 32-bit
  hooks, and `pkgs.steam`'s `extraEnv` lands in the FHS rootfs `/etc/profile` that
  `steam-run` sources, so unsetting them outside the sandbox is a no-op and every
  64-bit backend script dies with "wrong ELF class".
- **`luatools.lumenService` and the `steam` wrapper are exclusive by construction.**
  Both start Lumen; two start paths fight over the same CEF target, so the wrapper is
  only installed when the service is off.

## Work Guidance
- Diagnose in this order: (1) is the new file `git add -N`'d? (2) does
  `nix-instantiate --parse` pass on every `_*.nix`; (3) do the toggles evaluate as
  intended; (4) for a downgrade failure, re-pin the four rotating hashes; (5) for
  Millennium, bump the pin instead of touching the hash.
- Re-pin procedure: `curl -fsSL <url> | sha256sum`, `nix hash convert --hash-algo
  sha256 --to sri <hex>`, and eyeball the body first.
- Keep option names and defaults upstream-compatible when changing behaviour; the
  README in upstream is the documented contract users read.
- `nix-crab-status` is the diagnostic surface: extend its probes and both renderers
  together, and keep `--json` keys stable — they are the machine-readable contract.

## Verification
- `nix-instantiate --parse modules/features/nix-crab/*.nix` and `nixfmt --check` on
  the same files.
- `nix eval --impure --json .#nixosConfigurations.NIXPC.config.programs.nix-crab` →
  the six toggles; `…config.programs.steam.package.name` → `steam-<version>`, **not**
  `millennium-steam`, while Millennium is off.
- `nix eval --impure --raw
  '.#nixosConfigurations.NIXPC.config.programs.nix-crab.slssteam.extraEnv.LD_PRELOAD'`
  → a store path ending `-cloud_redirect.so/cloud_redirect.so`, and the same store
  path as
  `…home-manager.users.davr.home.file.".local/share/CloudRedirect/cloud_redirect.so".source`
  (the dedupe contract).
- `nix eval --impure --json
  '.#nixosConfigurations.NIXPC.config.home-manager.users.davr.services.flatpak.remotes'`
  → `flathub` plus the `crghofficial` URL, and no `Selectively11` URL.
- `nix eval --impure --raw .#nixosConfigurations.NIXPC.config.system.build.toplevel.drvPath`
  — the gate that evaluates both halves; it is also what catches a module file that
  `import-tree` picked up by mistake.
- `nix build --impure --no-link
  .#nixosConfigurations.NIXPC.config.programs.nix-crab.downgrade.package` — the cheap
  rotation gate: realizes the wrapper and all four upstream FODs without paying for
  the whole system.
- `patchelf --print-rpath /nix/store/*-SLSsteam-audit-upstream/*.so` → empty, with
  `libssl`/`libcurl` still in `--print-needed`.
- `nix build --impure --no-link
  .#nixosConfigurations.NIXPC.config.programs.steam.package` — realizes the audit
  staging and the FHS wrapper (5 derivations when the fork package is already in the
  store). With `slssteam-moon.enable` flipped on it also builds the 32-bit fork from
  source (≈3.5 min on this box, verified 2026-11-19) and produces
  `SLSsteam-audit-moon`.
- Build `nix-crab-status` from `home.packages` with `nix-store -r`, then run it and
  `--json | jq .` — the script has no test suite, so a live run is the check.
- Runtime, after `nixos-rebuild switch`: `nix-crab-status` reports the wired hook,
  and Steam starts with SLSsteam's `LD_AUDIT` plus CloudRedirect's `LD_PRELOAD`.

## Child DOX Index
- none — flat directory, no subtree
