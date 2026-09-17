---
name: dendritic-compose2nix-docker-feature
description: "Add a Docker Compose stack as a feature module in the dendritic flake (~/.config/dendritic or any dendritic-pattern flake): compose2nix invocation flags, the _-prefixed generated module, hand-written wiring for child images, store-free secrets, data-disk mount ordering, and tailnet exposure with host tailscaled. Use when asked to run a compose service as a NixOS feature, when compose2nix output breaks flake eval, or when a container must appear on a tailnet."
---

# Docker Compose stack as a dendritic feature module

Verified on cernoh/dendritic, 2026-09 (feature `paseo`, issue #201).

## Layout

```
modules/features/<name>/
  compose.yaml        source of truth (committed)
  _<name>.nix         compose2nix output, `_` prefix, imported explicitly
  <name>-image/       child image context (Dockerfile), if agents/binaries are needed
  default.nix         flake-parts module: `flake.nixosModules.<name>`
```

`import-tree` auto-registers every `*.nix` under `modules/`, so a generated
NixOS module at `modules/features/<name>/<name>.nix` breaks whole-flake eval.
The `/_` path exclusion keeps `_<name>.nix` out; `default.nix` then does
`imports = [ ./_<name>.nix ];`.

## Generate

```bash
cd modules/features/<name>
nix run github:aksiksi/compose2nix -- \
  -inputs compose.yaml -output _<name>.nix -project <name> \
  -runtime docker -check_bind_mounts -write_nix_setup=false
```

- `-runtime docker` — default is `podman`; NixOS `virtualisation.oci-containers.backend` must match.
- `-write_nix_setup=false` — drops `virtualisation.docker.enable` and `autoPrune.enable`. The
  flake's `docker` feature owns the daemon (`attrs/desktop -> act -> docker`); `autoPrune` is a
  host-wide prune policy that does not belong in an app feature.
- Declare the backend in `default.nix`: `virtualisation.oci-containers.backend = lib.mkDefault "docker";`
- Output is NOT nixfmt-formatted. Format with the locked nixpkgs nixfmt before commit
  (the repo's `nix run .#formatter` is broken; use `nix fmt -- --check <files>` or the
  `nixfmt` binary from `inputs.nixpkgs.legacyPackages.<system>`).

## What the generated file gives you

- `virtualisation.oci-containers.containers."<container_name>"` (or the service name).
- `systemd.services."docker-<container_name>"` — extend it from `default.nix`
  (`after`, `requires`, `unitConfig.RequiresMountsFor`, `serviceConfig.ExecStartPre`);
  list-valued options merge by concatenation, `unitConfig` values merge as `unitOption`.
- `systemd.services."docker-network-<project>_default"` + `systemd.targets."docker-compose-<project>-root"`.

## Wiring the generated file cannot express

- **Child image.** Do not use compose `build:` (compose2nix runs `docker build` on every start).
  Instead `image: <tag>` in compose, `pull = "never"` on the container, and a oneshot that builds
  from a store path with a staleness label:

  ```bash
  context=<store-path of ./<name>-image>
  current="$(docker image inspect --format '{{ index .Config.Labels "<name>.context" }}' <tag> 2>/dev/null || true)"
  [ "$current" = "$context" ] || docker build --label "<name>.context=$context" -t <tag> "$context"
  ```

  Order it `before = [ "docker-<name>.service" ]`, and give the container unit
  `after`/`requires` on the build unit. `pull = "never"` gives a clear "image not found"
  on first boot instead of a Docker Hub 404.

- **Secrets out of the store.** Never put an env secret in compose `environment:`. Use
  `environmentFiles = [ "${user.home}/.config/<name>/<name>.env" ]` plus an `ExecStartPre`
  root script that creates the file on first start (random value from
  `head -c 16 /dev/urandom | od -An -tx1 | tr -d '[:space:]'`, `install -d -m 0700 -o USER -g GROUP`,
  `chmod 0600`). ExecStartPre runs before `docker run`, so `--env-file` finds it.
  Note: a deployment env var then overrides a value written into the app's own config file.

- **Data disk ordering.** For bind mounts on a `nofail` filesystem, add
  `unitConfig.RequiresMountsFor = [ "<dir1>" "<dir2>" ]` to the container unit. A missing
  mount then fails the unit instead of letting the app initialise state onto the root fs.

- **Tailnet exposure.** `services.tailscale.serve` in nixpkgs only accepts the newer
  Tailscale *Services* config format (`{"version":"0.0.1","services":{"svc:x":{...}}}`), which
  needs admin-side Service resources. For a plain tailnet URL use host `tailscaled` plus a
  oneshot running `tailscale serve --bg --yes --http=80 http://127.0.0.1:6767`
  (`--http=80` yields `http://<node>/`; any port works, HTTPS needs tailnet certificates —
  check `tailscale status --json | jq .CertDomains`). Guard idempotence with
  `tailscale serve status --json | jq -e --arg t "$target" '[.. | objects | .Proxy? // empty] | index($t)'`
  and wrap the unit in `lib.mkIf config.services.tailscale.enable`. Root is required:
  `tailscale serve` as a normal user fails with "Access denied: serve config denied" unless
  `tailscale set --operator=$USER` ran once. Keep the container port on loopback.

## Verification traps

- `git add` new files before `nix eval .#` — untracked files are invisible to flake source copies.
- `nix eval --json .#nixosConfigurations.<HOST>.config.systemd.services.<unit>` fails with
  `The option '...startLimitBurst' was accessed but has no value defined`. Evaluate single
  fields instead (`| jq '{after, requires, unitConfig}'`).
- `nix build .#nixosConfigurations.<HOST>.config.system.build.toplevel --impure` is the real
  gate; then run the container by hand with the same ports/env/volumes to prove the app.
- STE lint issue and PR prose before creating them (`nix shell nixpkgs#python3`).
