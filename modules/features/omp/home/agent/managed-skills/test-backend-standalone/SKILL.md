---
name: test-backend-standalone
description: "Start backend server standalone in TCP mode and test API endpoints via curl, bypassing KOReader GUI. Use when testing backend features, writing automated tests, or debugging API issues."
---

# Test Backend Features Standalone

Start the Rust server in TCP mode and test API endpoints directly via curl, bypassing KOReader entirely.

## When to use

- Testing backend API endpoints (auth, sync, sources, etc.)
- Debugging backend issues without launching KOReader GUI
- Writing automated tests for backend functionality
- Quick verification that endpoints work before testing UI integration

## How

```bash
# 1. Build the server (if not already built)
cd backend
cargo build -p server

# 2. Start server in TCP mode
RAKUYOMI_USE_TCP=1 RAKUYOMI_TCP_PORT=8787 RUST_LOG=info \
    ./target/debug/server /tmp/rakuyomi-test-data &
SERVER_PID=$!

# 3. Wait for readiness
for i in {1..30}; do
    curl -s http://127.0.0.1:8787/health >/dev/null 2>&1 && break
    sleep 1
done

# 4. Test endpoints
curl -s http://127.0.0.1:8787/track/services
curl -s -X POST http://127.0.0.1:8787/track/anilist/auth-url

# 5. Cleanup
kill $SERVER_PID
rm -rf /tmp/rakuyomi-test-data
```

## Why this works

The backend server supports two modes:
- **UDS mode** (default): Unix domain socket at `/tmp/rakuyomi.sock`, used by the Lua plugin on Unix platforms
- **TCP mode**: TCP on `127.0.0.1:8787`, enabled via `RAKUYOMI_USE_TCP=1`

TCP mode is ideal for testing because:
- No KOReader GUI needed
- Direct HTTP access via curl
- Faster iteration (no plugin startup overhead)
- Works in CI/automated environments

## What NOT to do

- Don't try to call Lua methods via the HTTP inspector (port 8080) — it's read-only for widget tree traversal, not an RPC endpoint
- Don't use UDS mode for testing — curl can't easily talk to Unix sockets
- Don't launch KOReader just to test backend API — it's slower and requires the debug HTTP server to be manually enabled
