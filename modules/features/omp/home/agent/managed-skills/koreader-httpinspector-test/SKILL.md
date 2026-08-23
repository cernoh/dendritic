---
name: koreader-httpinspector-test
description: Test KOReader plugins programmatically via the HttpInspector built-in plugin on port 8081.
---

# Testing KOReader plugins via HttpInspector

KOReader's built-in `HttpInspector` plugin exposes plugin internals for programmatic testing over HTTP on port 8081 (default).

## Discover the endpoint

1. List top-level UI widgets:
   ```
   http://<kindle-ip>:8081/koreader/ui/
   ```
   Find the plugin widget (e.g., `StoryGraphPlugin`).

2. Plugin endpoint is at `/koreader/ui/<plugin-name>/`:
   ```
   http://<kindle-ip>:8081/koreader/ui/storygraph/
   ```

## Expose test methods

In the plugin Lua class, name methods `test*()`:
```lua
function MyPlugin:testPing()
    return { ok = true }
end
```

## Call methods

- **Path segments for arguments** — not query params.
  ```
  http://<kindle-ip>:8081/koreader/ui/storygraph/testSetCredentials/user@example.com/secret/
  ```
- **Trailing slash** → JSON response.
- **No trailing slash** → HTML documentation page.
- HttpInspector captures the return value and serializes it as JSON.

## Quick test scripts

Keep a `test/` folder with language-specific runners:

```javascript
// test/httpinspector_tests.js
const BASE = 'http://<kindle-ip>:8081/koreader/ui/<plugin-name>';
async function call(method, args = []) {
    const url = `${BASE}/${method}/` + args.map(encodeURIComponent).join('/');
    const res = await fetch(url, { timeout: 30000 });
    return { ok: res.ok, status: res.status, body: await res.text() };
}
```

## Common gotchas

- **State reads can be stale**: `HttpInspector` serializes the in-memory Lua object. Mutating calls execute, but a fresh `testGetState()` call is needed to see updated disk state.
- **Tests can clobber user config**: If a `testRunAll()` method writes fake credentials, snapshot real values at the start and restore them at the end.
- **Plugin code is cached**: After editing a plugin file, restart KOReader or use `koreader.sh --restart` so the new code loads into memory.
- **Arguments with special characters** (`@`, `+`, spaces) must be URL-encoded before being placed as path segments.
