---
name: nix-git-input-fetch-broken
description: "Diagnose and work around nix failing to fetch git+https flake inputs or git sources on this host (\"Failed to fetch git repository\"): the git transport is broken even for github.com, so pin a tarball archive URL or a curl-based fetch instead."
---

# `nix` cannot fetch git+https inputs on this host

Measured on NIXPC (x86_64-linux, NixOS, 2026-09-21).

## Symptom

```
nix flake lock
  … while fetching the input 'git+https://host/owner/repo.git?ref=v1.0'
  error: Failed to fetch git repository 'https://host/owner/repo.git'
```

The message carries no cause, even with `--debug`. The failure is not about
the remote host: it reproduces against github.com.

## The decisive probes

```bash
# 1. Broken for ANY host, including github.com:
nix flake metadata --json "git+https://github.com/tjarvstrand/dojjo.git?ref=v0.2.2"

# 2. But the git CLI works, and so does the curl-based fetcher:
git ls-remote https://github.com/tjarvstrand/dojjo.git | head -1
nix store prefetch-file --json https://github.com/tjarvstrand/dojjo/archive/refs/tags/v0.2.2.tar.gz

# 3. The API-based `github:` scheme works (it uses HTTP, not git):
nix flake metadata github:tjarvstrand/dojjo      # resolves, then complains about a missing flake.nix
```

Probe 1 failing while 2 and 3 succeed means the `git` transport that Nix uses
for flake inputs is broken. A proxy in the environment is NOT the cause here
(`printenv | grep -i proxy` and `git config --get http.proxy` are both empty).
The `github:` scheme only covers github.com, so it does not help for a fork
that lives on another host.

## Workaround

Pin the input as a tag archive. Nix fetches it over HTTP, which works.

```nix
retrosmart-cursor = {
  # Tag archive, not `git+https://…?ref=v2.0.1`: this host cannot fetch a git
  # input. Name the reason in the comment so nobody "fixes" it back.
  url = "https://github.laiyagushi.com/useless-anvil/retrosmart-cursor/archive/refs/tags/v2.0.1.tar.gz";
  flake = false;
};
```

`nix flake lock` then records the tree:

```json
{ "type": "tarball", "url": "…", "narHash": "sha256-…", "lastModified": 1788888659 }
```

Two properties to rely on:

- Nix unpacks the archive and uses the repository root as the input path, so
  the top-level directory that GitHub adds to the archive does not appear
  (`source root is source` in a build). The same layout as a `git+https` input.
- The archive has to include the `.git`-independent build files. A repository
  that builds from `.git` metadata alone will not work this way.

For a source that is not a flake input at all, `pkgs.fetchzip { url; hash; }`
uses the same code path and works.

## Do not

- Do not chase the missing cause. There is no flag that reveals it, and
  `--debug` shows only "fetching Git repository …".
- Do not switch to the `github:` scheme for a non-github host. It cannot
  express one.
- Do not conclude the remote host is down. `curl -I <url>` and
  `git ls-remote <url>` both succeed from the same machine.

## Verification

```bash
nix flake lock                    # adds the tarball input, no error
nu -c 'open --raw flake.lock | from json | get nodes."<name>".locked | to json'
nix build .#<package that consumes the input>
```

A locked input whose `type` is `tarball` with a `narHash` is complete. The
build then proves the tree layout.
