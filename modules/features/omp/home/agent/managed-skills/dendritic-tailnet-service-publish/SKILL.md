---
name: dendritic-tailnet-service-publish
description: "Publish a loopback service on the tailnet from a dendritic feature: the opt-in tailscale serve oneshot unit, reading the port back from the home-manager service so the proxy cannot drift, plus the verification recipes (synthetic nixosSystem harness for cross-scope option guards, port-override coupling proof, unit text + systemd-analyze verify, and locating STE lint violations)."
---

Apply when a dendritic feature serves a web app on loopback and a phone or
another tailnet node must reach it. Verified on cernoh/dendritic while adding
`herdr-web` (issues #200/#203/#205), 2026-09. Reference implementation:
`modules/features/herdr-web/default.nix` (the `flake.nixosModules.herdr-web`
half).

## Shape

- Keep the app bound to `127.0.0.1`. An unauthenticated local service must not
  widen its own bind. Tailscale proxies from the tailnet to loopback and
  terminates TLS, so the app gains an HTTPS origin anyway (which is what
  unlocks PWA install and service-worker notifications).
- Declare the knob on the **NixOS** module (`flake.nixosModules.<name>`), not
  the home-manager one: `tailscale serve` runs as root, so a user unit cannot
  apply it. Default it off (`lib.mkEnableOption`); the tailnet is the user's.
- Read the listen address **back** from the home-manager service instead of
  declaring it twice:

  ```nix
  hmServices = config.home-manager.users.${config.dendritic.userName}.services;
  bridge = if hmServices ? <name> then hmServices.<name> else throw "…";
  ```

  One owner per fact. Declaring `port`/`bind` on both sides and pushing one
  into the other does not remove the coupling (writing an undeclared HM option
  fails the same way) and adds a second default to drift from.
- Guard the read with `?` plus a `throw` that names the missing module. The
  throw sits behind the same lazy read as `ExecStart`, so a disabled option
  never reaches it. Assert `config.services.tailscale.enable` too.
- Unit: `Type = "oneshot"`, `RemainAfterExit = true`,
  `ExecStart = "${lib.getExe pkgs.tailscale} serve --bg --https=<port> http://<bind>:<port>"`.
  `--bg` writes the mapping into tailscaled and returns. `ExecStop` must be
  port-scoped: `tailscale serve --https=<port> off`. NEVER `tailscale serve
  reset` (clears the user's whole serve config). Add
  `Restart = "on-failure"` with `RestartSec = 15`: tailscaled is *started*, not
  necessarily online, when a boot-time oneshot runs.
- Enable it in the one host that runs the app, and record the delta in
  `modules/hosts/AGENTS.md` plus the feature row in `README.md`.

## Verification (nothing here can be guessed)

- **Cross-scope option guard** — eval a synthetic system instead of contorting
  the real hosts. Build it with `lib.nixosSystem` over the modules you need
  (`f.inputs.home-manager.nixosModules.default`, `f.nixosModules.<name>`, a
  module declaring `options.dendritic.userName`, `users.users.<user>`, and
  `home-manager.users.<user>`), then eval three cases with `--apply`:
  off+module-absent (expect success and no unit), on+module-absent (expect the
  throw message), on+module-present (expect `ExecStart`). HM needs
  `users.users.<user>` to exist or it fails on `config.users.users.<name>.name`
  — that error is the harness, not the feature.
- **Coupling proof** — set the app port to a sentinel (e.g. 8123) through
  `home-manager.users.<user>.services.<name>.port`, confirm the serve
  `ExecStart` follows to that port, then revert and re-check the default. This
  is the test that proves the read, not the comment.
- **Unit text** — `config.systemd.units."<n>.service".text` gives the rendered
  unit; `.unit` is a **store path**, not text (and cannot be built directly).
  Pipe `.text` to `systemd-analyze verify <file>` for a real syntax gate.
- **Host gates** — pure
  `nix eval --accept-flake-config --raw ".#nixosConfigurations.<HOST>.config.system.build.toplevel.drvPath"`
  for each host (CI's purity gate), then `nix flake check --impure`.
- **Do not apply the mapping yourself** unless you hold root. `sudo -n` needs a
  password here. Prove the CLI surface read-only instead (`tailscale serve
  status`, `tailscale serve --help`), and note the mapping appears only after
  the next `nixos-rebuild switch --impure`. `tailscale serve status --json`
  prints `{}` while empty.
- Report the phone URL from `tailscale status --json | .Self.DNSName`, never
  from memory of the tailnet.

## STE lint iteration (issue/PR prose)

The linter (`python3 .github/scripts/ste-lint.py`) does not name the offending
sentence. Replicate its splitter on the draft to find it, then split or shorten
exactly that sentence:

```python
import re, sys
t = re.sub(r"`[^`]*`", " ", open(sys.argv[1]).read())
for line in t.split("\n"):
    s = re.sub(r"^\s*#{1,6}\s*", "", line.strip()).strip()
    if not s: continue
    s = re.sub(r"^\s*[-*]\s+", "", s)
    for p in re.split(r"(?<=[.!?:])\s+(?=[A-Z0-9\"'\-])", s):
        if len(re.findall(r"[A-Za-z0-9][A-Za-z0-9'\-/]*", p)) > 20:
            print(p)
```

Drop `-`/`*` line prefixes, or the whole bullet list counts as one paragraph and
trips `long_paragraph(>6s)`. Backticked spans are stripped before counting, so
they never inflate a sentence — the offending words are always prose.
