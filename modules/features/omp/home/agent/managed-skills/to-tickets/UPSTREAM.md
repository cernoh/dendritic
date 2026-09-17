# Upstream

- Source: `https://github.com/mattpocock/skills`, file `skills/engineering/to-tickets/SKILL.md`.
- Commit: `74ca5fe077456a0b3b2f5310cf9430999fd0b5fd` (2026-09-17).
- Licence: MIT. The upstream notice is in `LICENSE-MIT.txt`.
- Local changes:
  1. `## Where the tickets live` replaces the tracker paragraph. The tickets publish as GitHub issues, and the label vocabulary and the blocking commands come from `skill://wayfinder`.
  2. Step 5 names the two-pass order: create every issue, then wire the blocking edges by database id.
  3. The local-markdown branch and the local ticket template are dropped, because the tracker is GitHub only.
