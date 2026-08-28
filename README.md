# dendritic

Dendritic-pattern master flake for my machines, replacing `~/.config/home-manager-v3`.
Every file under `modules/` is a top-level [flake-parts](https://flake.parts) module,
auto-registered by [import-tree](https://github.com/vic/import-tree) — see the
[dendritic pattern](https://github.com/mightyiam/dendritic).

## Hosts

| Host | System | Desktop | Notes |
|---|---|---|---|
| `NIXPC` | x86_64-linux | MangoWM + Noctalia Shell | NVIDIA GPU, gaming (Steam bundle + tools), MCP containers |
| `ASAHI` | aarch64-linux | Niri + Noctalia Shell | Apple Silicon via [nixos-apple-silicon](https://github.com/tpwrules/nixos-apple-silicon), Widevine DRM Firefox |

## Rebuild

```sh
# NIXPC
sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#NIXPC

# ASAHI
sudo nixos-rebuild switch --impure --flake ~/.config/dendritic#ASAHI
```

`--impure` is required: on the target machine the core module consumes
`/etc/nixos/hardware-configuration.nix` (which stays out of this repo by design).
Evaluated anywhere else, hosts fall back to a placeholder root filesystem —
evaluation still succeeds, deploys only happen from the machine itself.

## Features

One directory per app/concern under `modules/features/`. Import IS enabling:
NixOS-scoped features export `flake.nixosModules.<name>`, home-manager-scoped ones
export `flake.homeManagerModules.<name>`; host presets and the HM glue wire them up.

| Feature | What importing it enables |
|---|---|
| `act` | GitHub Actions local runner via [nektos/act](https://github.com/nektos/act); composes `docker`, ships a default runner image in `~/.actrc`. Enabled by the `desktop` bundle |
| `davinci` | DaVinci Resolve (from the `davinci` input) |
| `docker` | Docker runtime + compose CLI; sibling module `mcpContainers` provisions the omp MCP stack (scrapling :8000, agentwebsearch-mcp :8902, hindsight host-networked) as systemd-managed oci-containers |
| `fish` | fish shell config + companion CLI tools (direnv hook comes from `programming`) |
| `gaming-tools` | Lutris, MangoHud, Wine, Vulkan tooling and friends — beyond Steam |
| `ghostty` | Ghostty terminal with live-editable out-of-store config |
| `lazygit` | lazygit built by this flake, into `environment.systemPackages` |
| `mango` | MangoWM session + its home-manager user config |
| `niri` | Niri compositor + session, live-editable `config.kdl` |
| `nixpc-desktop` | NIXPC desktop application suite (browsers, media, utilities) |
| `noctalia` | Noctalia desktop shell v5 (bars, panels, launcher, lock screen); settings are per-host |
| `noctalia-greeter` | greetd login UI matching Noctalia; each host picks `--session <compositor>` inline |
| `nushell` | nushell as secondary interactive shell, incl. `nixpc-rebuild` / `asahi-rebuild` helpers |
| `nvf` | Neovim via [nvf](https://github.com/notashelf/nvf) (languages, keymaps, nixd config) |
| `omp` | [Oh My Pi](https://github.com/cernoh/omp-flake) agent CLI; `~/.omp` symlinked out-of-store |
| `opencode` | OpenCode agent CLI config tree, out-of-store |
| `posy-cursors` | Posy cursor themes |
| `programming` | Dev environment: git, direnv, tmux, zellij, gh, editors' companions |
| `steam` | `programs.steam` + protontricks + compat packages |
| `stremio-kai` | Stremio-Kai mpv configuration copied writable into `~/.config/mpv` |
| `usb-automount` | udev-triggered USB mounting under `/run/media/<user>` with mount/unmount notifications |
| `wayland-base` | Qt Wayland platforms, Chromium/Electron ozone flags, Firefox Wayland, fuzzel |
| `widevine` | Widevine DRM-enabled Firefox (aarch64 — without it Netflix-class playback breaks on Asahi) |

## Layout

```
modules/
  parts.nix           shared flake-parts plumbing: systems list, output-option declarations
  attrs/              machine-class bundles composing features by name
    desktop/            core + network + audio + usb-automount + home-manager glue
    gaming/             the Steam bundle
    programming/        system-side dev tools (HM side comes from the programming feature)
  features/<app>/     opt-in feature modules (the table above)
  hosts/<HOST>/       host presets producing nixosConfigurations.<HOST>
  system/             cross-host system concerns: core, network, audio, drivers, home-manager glue
```

Conventions:

- **Auto-registration:** every file under `modules/` is imported as a flake-parts module —
  no manifest. Corollary: a parse error in any file breaks the whole flake;
  check new files with `nix-instantiate --parse <file>`.
- **`_` exclusion:** paths containing `/_` are skipped by import-tree. Data-only siblings
  (`_languages.nix`, host settings files, `_*.pkg.nix` derivations) use it and are
  imported explicitly by their owning module.
- **Lower-level modules are values:** features store NixOS/HM modules under
  `flake.nixosModules.*` / `flake.homeManagerModules.*`; hosts assemble them by name.
- **Out-of-store symlinks:** configs meant to stay live-editable (fish, nvf, niri,
  ghostty, omp, opencode) link back into this checkout instead of living in the store.

## Verification ladder

Cheapest first; stop at the rung that covers your change:

1. Parse: `nix-instantiate --parse <file>`
2. Targeted evals: `nix eval .#nixosConfigurations.<HOST>.config.<option>` (also
   `homeManagerModules` renders, rendered artifacts under
   `nix eval ... config.system.build.toplevel.drvPath`)
3. Rendered-artifact checks: read generated files out of evaluated derivations
4. Whole flake: `nix flake check --impure`

CI (`.github/workflows/`) runs a changed-file nixfmt check, an eval matrix over both
hosts, and a weekly flake-lock bump.

## Known boundaries

- **hardware-configuration.nix stays out of the repo by design** — root/boot come from the
  machine's `/etc/nixos/hardware-configuration.nix` at deploy time (see Rebuild above).
- **Cross-machine evaluation** shows a `hardwareFromMachine … placeholder root filesystem`
  warning; that is the documented boundary above, not a bug.
- **Asahi inputs must follow nixpkgs** (`inputs.nixpkgs.follows = "nixpkgs"`): apple-silicon
  support modules inject packages into host configs, and without the follow they resolve
  against the input's own eval system and break `ASAHI` evals from other machines (#16).
- **Asahi bootchain builds locally**: tpwrules/nixos-apple-silicon publish no
  binary cache for linux-asahi/uboot-asahi/m1n1 (`nixos-apple-silicon.cachix.org`
  covers everything else), so every `asahi` input bump rebuilds the ~4 heavy
  bootchain derivations on the Mac (issue #73). Plan for it: reboot after a
  bump (`/run/reboot-required` banner, issue #72) and follow the rescue
  runbook in `modules/hosts/ASAHI/RESCUE.md` when rolling back.
