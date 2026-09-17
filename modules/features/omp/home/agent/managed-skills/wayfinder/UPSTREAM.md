# Upstream

- Source: `https://github.com/mattpocock/skills`, file `skills/engineering/wayfinder/SKILL.md`.
- Commit: `74ca5fe077456a0b3b2f5310cf9430999fd0b5fd` (2026-09-17).
- Licence: MIT. The upstream notice is in `LICENSE-MIT.txt`.
- Local changes:
  1. The tracker is GitHub Issues. The `## GitHub operations` section holds the commands. Upstream defers to a tracker document written by `setup-matt-pocock-skills`, which this flake does not carry.
  2. The ticket types name the local skills: `skill://research`, `skill://prototype`, `skill://grill-me-html`, and `skill://domain-modeling`.
  3. `## The grills run as a form` is new. Each HITL grill runs through the `grill_form` tool of `skill://grill-me-html`, and the record renders with `render_html`.
  4. `## Handing off` is new. A cleared map hands to `skill://to-spec`, then `skill://to-tickets`, then `skill://implement`.
  5. The frontier query calls `~/.omp/agent/scripts/wayfinder-frontier.sh`.
  6. The `wayfinder_view` tool is new, and the GitHub operations list it: it serves the whole map as one live HTML page with the solved and remaining counts.
