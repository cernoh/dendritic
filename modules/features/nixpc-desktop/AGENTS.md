# nixpc-desktop — NIXPC-only desktop bundle

## Purpose
The x86_64 (NIXPC) desktop bundle: GPU/Mango tuning env, the per-user desktop programs, and host-specific browser and media flags that have no meaning on ASAHI.

## Ownership
`default.nix` only. Exports `flake.homeManagerModules.nixpcDesktop`; import is enabling. Everything in here is NIXPC-scoped by construction — a value that only makes sense on this host's NVIDIA/wlroots/Mango stack does not belong in a shared `system/` or `features/` module.

## Local Contracts
- **Vulkan MUST stay disabled for Brave on this host.** Chromium refuses it under native Wayland: the GPU process logs `'--ozone-platform=wayland' is not compatible with Vulkan. Consider switching to '--ozone-platform=x11' or disabling Vulkan` (`ui/ozone/platform/wayland/gpu/wayland_surface_factory.cc`) and the window is mapped but never painted. The failure is silent from the user's side — the browser process, GPU process, and all renderers stay alive, `mango` lists a normal `brave-browser` toplevel, and the zygote errors in the launching terminal are a *different*, benign thing. What you see is a transparent rectangle with the desktop showing through, or uninitialised garbage after any resize that forces a new buffer.
- **The disable is load-bearing, not a counterpart to an enable.** Chromium auto-enables Vulkan when it detects the NVIDIA ICD, so dropping the `--enable-features=Vulkan,…` line is not sufficient on its own; `--disable-features` must name `Vulkan`, `VulkanFromANGLE`, and `DefaultANGLEVulkan`. Verified by A/B: same binary, same fresh profile, same `--ozone-platform=wayland` — GPU-on with Vulkan allowed renders garbage, GPU-on with Vulkan disabled renders correctly.
- **Only the last `--enable-features`/`--disable-features` occurrence reaches Chromium.** The brave package's own `commandLineArgs` defaults are prepended to this module's, so this module's `--disable-features` must repeat any package default it wants to keep (`OutdatedBuildDetector`, `UseChromeOSDirectVideoDecoder`) instead of assuming the two lists merge.
- **`--ozone-platform=wayland` and the generic Chromium ozone flag live in `features/brave`.** This module adds only the NIXPC-specific tuning. `commandLineArgs` lists merge across modules, which is how the two halves combine — but the merge is also how an unsupported pair got assembled in the first place, so a flag added here must be checked against everything `features/brave` and the package contribute.
- **Do not "fix" a blank Brave window by reaching for `--disable-gpu`.** It masks the real contract by turning off hardware acceleration entirely. The Vulkan disable alone restores correct rendering with the GPU still active.
- **The residual Vulkan error line is expected.** Once Vulkan is disabled the GPU process still logs that same `ERROR` line while probing the driver. It is not a regression signal, and rendering is correct — judge by the window's pixels, not by the absence of that line.

## Work Guidance
- To re-verify a Brave flag change without a rebuild, bypass the generated per-user shim, which hardcodes the flags at `/etc/profiles/per-user/<user>/bin/brave`: call the package's `bin/.brave-wrapped` directly with an explicit `--user-data-dir` under `/tmp`. Passing extra flags to `brave` on PATH does **not** override the injected ones — the shim appends its own and they win.
- Inspect compositor-side window state with `wlrctl toplevel list` and Mango's `mmsg`. `mmsg` needs `MANGO_INSTANCE_SIGNATURE`, which the compositor sets *after* `exec` and so is absent from `/proc/<pid>/environ`; the value is the socket path, `/run/user/$UID/mango-<pid>.sock`.
- Screenshot to judge rendering: `grim` captures the whole 5760×1080 three-monitor layout, so confirm which output a window landed on before concluding it is blank.

## Verification
- `nix-instantiate --parse modules/features/nixpc-desktop/default.nix`
- `nix eval --impure --json .#nixosConfigurations.NIXPC.config.home-manager.users.<user>.programs.brave.commandLineArgs` — the merged list is what Chromium actually receives; read it rather than trusting either module alone.
- A GPU-path change is only proven by a rendered frame, not by eval or by a clean log. See Work Guidance.

## Child DOX Index
- None — single `default.nix`.