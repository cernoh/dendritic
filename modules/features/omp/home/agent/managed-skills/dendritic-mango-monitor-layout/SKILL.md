---
name: dendritic-mango-monitor-layout
description: "Edit monitor positioning/layout in the dendritic mango feature (modules/features/mango/default.nix): verify real connector-brand identity via wlr-randr EDID before trusting config comments, and flip monitorrule x positions together with tagmon bind targets to keep spatial H/L key semantics."
---

# Dendritic mango monitor layout

Use when changing monitor arrangement in `modules/features/mango/default.nix` (NIXPC): flipping monitors left/right, adding/removing outputs, or debugging wrong cursor/window edge behavior between the two displays.

## Facts (NIXPC, EDID-verified 2026-09-07)

- DP-1 = AOC 24G2W1G3- (1920x1080, 165 Hz capable)
- DP-2 = HUAWEI AD80HW (1920x1080)
- Both monitors are 1920 px wide, so a clean side-by-side offset is `x:1920` for the right monitor.
- Config comments have historically MISLABELED these (claimed DP-1 = HUAWEI, DP-2 = AOC). Do not trust comments; the mislabel caused a reversed layout (issue #142).
- Desk spec (issue #114): AOC LEFT, HUAWEI RIGHT. Mouse off the AOC's right edge must land on the HUAWEI.

## Procedure

1. Read `modules/features/mango/default.nix` (settings.monitorrule + the tagmon binds and their comments).
2. Get ground truth from the live session (this repo is often edited ON NIXPC under mango):
   `nix run nixpkgs#wlr-randr`
   Match connector names (`DP-1`/`DP-2`) to Make/Model and read each `Position:` — this is what mango actually applies.
3. Edit `monitorrule` x positions so the virtual layout matches the desk. Left monitor gets `x:0`; right monitor gets `x:1920` (equal widths today — re-check if hardware changed).
4. When sides are flipped, ALSO swap the `tagmon` bind targets (`SUPER+ALT,H` / `SUPER+ALT,L`). Keys are spatial (vim h=left, l=right): H must target whatever monitor is LEFT, L the RIGHT one. Swapping layout without swapping binds inverts the user's muscle memory.
5. Update the comments to the EDID-verified identity (include the verification date + model) so the mislabel does not regress.
6. Verify:
   - `nix-instantiate --parse modules/features/mango/default.nix`
   - `nix build --impure .#nixosConfigurations.NIXPC.config.programs.mango.package` — the configFile derivation runs `mango -c -p` (build-time config validation)
   - Grep the built config (path is inside the wrapper at `<out>/bin/mango` or from the build log) for the `monitorrule = name:^DP-x$,x:...` lines and `bind = SUPER+ALT,...` lines to confirm content
   - `nix run nixpkgs#nixfmt-rfc-style -- --check modules/features/mango/default.nix`
7. Repo flow: worktree under `.worktrees/`, issue-linked PR, STE-lint title+body (`.github/scripts/ste-lint.py` via `nix run nixpkgs#python3`), PR title tagged `(#N)`.

## Pitfalls

- Pure host-eval CI (`Evaluate NIXPC/ASAHI`) can be red on main from an unrelated home-manager `.manpath` `fetchurl sha256` pure-eval error; `nix flake check --impure` and local impure eval are the reliable gates. Confirm pre-existing at `origin/main` before attributing.
- Do not edit in the main checkout when it has the user's in-flight changes; the mango file lives in the same repo tree (omp agent config etc.). Use a worktree and stage only the mango file.
- A live flip only applies after rebuild + mango session restart; there is no mango IPC to hot-reload (`mango msg` does not exist).
