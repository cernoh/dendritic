---
name: nushell-c-invocation
description: "Call Nushell from the bash tool with nu -c: stdin never binds to $in, so pipe producer output through a temp file and use open pipelines instead. Use when parsing JSON/YAML output of gh, omp, git, or nix with Nushell."
---

Verified on this workstation (nu 0.105), 2026-09-10. Five failures in one session traced to one mistake.

## `$in` never binds stdin under `nu -c`

Every stdin form fails, whatever the producer:

```bash
printf 'x\n' | nu -c '$in | str length'        # error: no input value was piped in
command | nu -c '$in | from json | get k'      # same error
```

Do not reach for `$in`, and do not assume a JSON producer pipes in.

## What works: stage the output in a file, then `open`

```bash
gh api repos/OWNER/REPO/issues > /tmp/x.json
nu -c 'open /tmp/x.json | where pull_request? == null | select number title'
```

```bash
omp models --json opencode-go > /tmp/m.json
nu -c 'open /tmp/m.json | get models | where id == "deepseek-flash" | select id name'
```

`open` infers JSON/YAML from the extension and content. Plain text works too:

```bash
nu -c 'open /tmp/log.txt | lines | where {|l| $l | str contains "error"}'
nu -c 'open --raw /tmp/log.txt | lines | length'
```

## Two traps next to it

- A `where` closure that pipes inside the predicate can raise `IncompatiblePathAccess { type_name: "string" }`. When that happens, filter in JavaScript via the `eval` tool, or read the file and slice it yourself.
- Prefer the `read` tool for text files. `read`, `nu -c 'open …'`, and JS `Bun.file` all work; only `$in` does not.

## Structured-output rule

The harness asks for Nushell over `jq` on JSON. Keep that, and pass the data through a file:

```bash
command ... > /tmp/out.json
nu -c 'open /tmp/out.json | get items | select number title | to md'
```

Reserve bash for invoking the producer, and JS `eval` for anything Nushell fights.
