# Tmux Reader

Read from running tmux panes for live debugging. Use when a process is running in a tmux session and you need to inspect its output — server logs, REPL state, test runners, build watchers, etc.

## Tools

| Tool | Purpose |
|------|---------|
| `tmux_sessions` | List all sessions, windows, panes with PIDs and running commands |
| `tmux_capture` | Capture visible content (or scrollback) from a pane |
| `tmux_send_keys` | Send keystrokes/commands to a pane |

## Workflow

1. **Discover**: `tmux_sessions` → see what's running where
2. **Read**: `tmux_capture` with `target: "session:window.pane"` → see current output
3. **Interact** (optional): `tmux_send_keys` → type commands, send Ctrl+C, etc.

## Target syntax

- `session:window.pane` — fully qualified (e.g. `dev:0.0`)
- `session:window` — defaults to pane 0
- `session` — defaults to window 0, pane 0
- Omit target in `tmux_capture` — uses the active pane

## Common patterns

### Read server logs
```
tmux_capture(target: "server:0.0")
```

### Read last N lines only
```
tmux_capture(target: "dev:1.0", lines: 50)
```

### Include scrollback history
```
tmux_capture(target: "dev:0.0", scrollback: true)
```

### Send Ctrl+C to stop a process
```
tmux_send_keys(target: "dev:0.0", keys: "C-c")
```

### Type a command in a REPL
```
tmux_send_keys(target: "dev:0.0", keys: "some-command")
tmux_send_keys(target: "dev:0.0", keys: "Enter")
```

## Notes

- `tmux_capture` strips trailing blank lines for cleaner output
- `tmux_send_keys` uses tmux key syntax: `C-c` = Ctrl+C, `Enter` = Return, `M-x` = Alt+X
- Use `literal: true` in `tmux_send_keys` to send text without key interpretation
- If no tmux server is running, tools report that clearly — start one with `tmux` or `tmux new -s <name>`
