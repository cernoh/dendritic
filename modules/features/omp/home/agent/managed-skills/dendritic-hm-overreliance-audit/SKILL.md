---
name: dendritic-hm-overreliance-audit
description: "Audit a dendritic flake for home-manager over-reliance per the homeless-dotfiles policy: grep HM option usage, classify against the delivery ladder, verify app flags and env reachability empirically, then file per-root-cause issues with acceptance criteria"
---

# Dendritic HM over-reliance audit

Audit a dendritic flake (this repo or similar) for home-manager over-reliance, per the `dendritic-homeless-dotfiles` repo skill (policy #93). Use when asked to find modules that over-rely on home-manager, re-audit after homeless fixes, or review features before merging.

## 1. Enumerate HM usage

```bash
grep -n "home\.file\|xdg\.configFile\|home\.sessionVariables\|home\.packages\|home\.activation\|home\.state\|systemd\.user" modules/features
grep -n "homeManagerModules\." modules
```

Sites to classify: `home.file`/`xdg.configFile` (content vs symlink), `home.sessionVariables`, `home.activation`, `programs.<app>.*` renders, `home.packages`.

## 2. Classify against the delivery ladder

| State | Verdict |
|---|---|
| out-of-store symlink (`config.lib.file.mkOutOfStoreSymlink`) for live-editable config (niri, ghostty, omp, opencode, posy-cursors) | OK — rung 5 exception |
| HM content for a static config | VIOLATION — escalate to store/flag/env (rungs 1-4) |
| HM content for an HM-bound integration (noctalia settings, nvf) | OK — blessed exception |
| store **copy** of a git-tracked file (`xdg.configFile."x".text = readFile ./x`) | VIOLATION — symlink it |
| `home.activation` materializing config into the user's live dir | suspect — can it be env/flag-scoped? |
| `home.sessionVariables` for env that must reach compositor/systemd-user processes | VIOLATION — profile channel only |

## 3. Empirical checks (do these before filing)

- App flag support: `app --help | grep -iE '\-\-config|-c '` — a `-c <file>`/`--config` flag makes a whole HM settings render homeless (mango case: `mango -c <file>`, `-p` for build-time validation).
- Env reachability: `fish -c 'echo $VAR'` (HM vars DO reach fish/nu), `tr '\0' '\n' < /proc/<compositor-pid>/environ` (they do NOT reach the greeter-spawned compositor — proven in #86), `systemctl --user show-environment` (not present for user units).
- Current running generation may predate the fix — attribute missing vars to gen staleness, not the module, before concluding.

## 4. File issues

One GitHub issue per root cause (group modules sharing a mechanism, e.g. one env-delivery issue listing all `home.sessionVariables` sites). Each issue: current state (file + lines), why it violates policy #93, the concrete homeless delivery (flag verified by name), acceptance criteria, host scope (NIXPC/ASAHI/both). Implementation later = one branch per issue, stacked PRs (Rule 3).
