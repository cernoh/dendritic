---
name: watcher-dev-stack-port-and-teardown
description: "Fix and verify dev-stack launchers that wrap deno --watch / dotnet watch: wake up on Address already in use, diagnose which process truly holds the port, kill watcher children with a process group instead of orphaning them, and choose the port policy. Use for nix run .#dev-all style concurrent watchers, AddrInUse (os error 98), or a port still held after Ctrl-C."
---

# Watcher dev stacks: busy port and child teardown

Applies to any launcher running two watchers side by side (`deno run --watch`, `dotnet watch`) — e.g. WFinfo-ext `nix run .#dev-all` (flake `apps.dev-all`).

## Symptom

```
error: Uncaught (in promise) AddrInUse: Address already in use (os error 98)
  Deno.serve({ port: PORT }, handler);
Watcher Process failed. Restarting on file change...
```

The stack looks alive but the frontend never serves; the watcher re-fails on every edit.

## Two independent defects

1. **`Deno.serve` throws `AddrInUse` synchronously** — it is not a rejected promise. An unguarded call surfaces as an unhandled rejection naming only the JS line, never the port. Wrap it:

   ```ts
   try {
     Deno.serve({ port: PORT }, handler);   // Deno prints "Listening on …" itself
   } catch (err) {
     if (err instanceof Deno.errors.AddrInUse) {
       console.error(`error: port ${PORT} is already in use`);
       console.error("  stop the process that holds it, or listen elsewhere: PORT=8765 deno task dev");
       Deno.exit(1);
     }
     throw err;
   }
   ```

   Do not print your own "listening" line after the call — it lies when the bind failed.

2. **The watcher's child survives a watcher-only kill.** `deno --watch` and `dotnet watch` run the real program as a child. `kill <watcher pid>` leaves that child alive *and holding the port*, so the next start fails. Fix in the shell wrapper:

   ```sh
   pids=()
   set -m                  # job control → each background job gets its own process GROUP
   stop() {
     trap - INT TERM EXIT
     for pid in "${pids[@]}"; do kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true; done
     sleep 0.5             # needs coreutils on PATH inside a nix writeShellScriptBin
     for pid in "${pids[@]}"; do kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true; done
     wait 2>/dev/null || true
   }
   trap stop INT TERM EXIT
   ```

   `set -m` works even in a non-interactive shell: verify the child's pgid differs from the script's (`ps -o pgid= -p $!`).

## Port policy — pick deliberately

Asymmetry that is intentional:

- **Direct launch (`deno task dev`)**: never switch ports silently. The operator asked for 8000; report that 8000 is taken and how to change it.
- **Supervising launcher (`dev-all`)**: honour an explicit `PORT` (busy `PORT` = start error), otherwise take the first free port upward and *print* the chosen URL.

Port probe with no dependencies (no `ss`/`lsof` needed, and `ss -p` cannot name a process owned by another uid — e.g. a Docker-published port):

```sh
port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
PORT=8000; while port_in_use "$PORT"; do PORT=$((PORT+1)); done; export PORT
```

## Diagnosis order

1. Read the real error text — `AddrInUse` is not a leaked server you wrote.
2. `docker ps --filter publish=<port>` first: Docker-published ports show as LISTEN with no process, and `curl` reveals the foreign server (`server: uvicorn`, nginx, …).
3. `pgrep -af 'deno|dotnet'` for orphans from a previous run.
4. Reproduce cheaply: `nix develop -c deno eval 'try { Deno.serve({port:8000, onListen:()=>{}}, ()=>new Response("x")) } catch(e){ console.log(e.name) }'`.

## Verification recipe

- Busy port, direct launch: must exit 1 with the port number, no stack-trace wall.
- `PORT=<free> deno task dev`: `Listening on http://0.0.0.0:<free>/`; probe two pages for 200/302.
- Launcher: `nix run .#dev-all` → prints `port 8000 is in use, trying 8001` and serves on 8001.
- Teardown: after terminating the launcher, `pgrep -af 'deno run -A --watch|dotnet watch'` is empty **and** the port probe fails. Empty pids alone does not prove the child is gone — always probe the port.
- Gates: `deno fmt --check && deno lint && deno check src && deno test -A src`, then `nix build --no-link .#checks.<system>.dashboard-*`.
