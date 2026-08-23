---
name: integration-test-infrastructure
description: "Create integration test infrastructure for client-server projects using mock server + bash test suite. Use when building clients that communicate with servers, especially cross-device (mobile app + external client)."
---

# Integration Test Infrastructure for Client-Server Projects

## When to Use
When building a client that communicates with a server (especially cross-device like mobile app + external client), create test infrastructure before or alongside implementation.

## Pattern

### 1. Mock Server (Python)
Create `scripts/mock-server.py` implementing all API endpoints the client expects:
- Use Python's `http.server` for simplicity (no dependencies)
- Return realistic mock data matching the real server's response format
- Handle all HTTP methods the client uses (GET, POST, etc.)
- Log requests for debugging: `print(f"[{self.command}] {args[0]}")`
- Use proper HTTP status codes (200, 400, 404)
- Return JSON with correct Content-Type headers

### 2. Integration Test Suite (Bash)
Create `scripts/test-plugin.sh` testing all client API calls:
- Accept server URL as argument for flexibility (mock vs real)
- Use helper functions: `assert_http_ok`, `assert_json_field`, `assert_json_array`
- Test in logical order: health check → list endpoints → detail endpoints → actions
- Parse JSON responses carefully (handle whitespace variations: `"id":1` vs `"id": 1`)
- Exit with proper codes: 0 = pass, 1 = fail, 2 = unreachable
- Make optional tests for features that may not be available (e.g., UI inspectors)

### 3. Convenience Runner
Create `scripts/run-tests.sh` that:
- Starts mock server on specified port
- Waits for server to be ready (poll with timeout)
- Runs test suite
- Cleans up server process on exit
- Returns test exit code

## Key Implementation Details

### Mock Server Path Parsing
For paths like `/api/v1/manga/1/chapters`:
```python
parts = path.split("/")  # ["", "api", "v1", "manga", "1", "chapters"]
id = int(parts[4])       # Index 4, not 3!
```
Common bug: off-by-one in array indices when extracting IDs from paths.

### Bash JSON Parsing
Handle both compact and pretty-printed JSON:
```bash
# Wrong: only matches "id":1
grep -o '"id":[0-9]*'

# Right: handles "id": 1 and "id":1
grep -o '"id":[[:space:]]*[0-9]*' | grep -o '[0-9]*$'
```

### Test Organization
```
scripts/
├── mock-server.py    # Mock server (standalone, no deps)
├── test-plugin.sh    # Integration tests
└── run-tests.sh      # Convenience runner
```

## Testing Against Real Server
Same test suite works against real server by passing different URL:
```bash
# Mock server
./scripts/run-tests.sh

# Real device
./scripts/test-plugin.sh http://192.168.1.100:8080
```

## Benefits
- Catch API contract mismatches early
- Test client without running real server
- CI-friendly (no external dependencies)
- Documents the API contract in code
- Enables TDD for client-server integrations
