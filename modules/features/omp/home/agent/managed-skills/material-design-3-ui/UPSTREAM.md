# Upstream

- Source: `https://github.com/skydashnet/material-design-3-ui-skill`.
- Commit: `a7d28f28251b64740b74dd0046971f23fbe74758` (2026-08-18).
- Skill version: `1.1.0`.
- Vendored files: `SKILL.md` and the thirteen files under `references/`. The reference files are unchanged.
- Licence: MIT. The upstream notice is in `LICENSE-MIT.txt`.
- Local changes:
  1. The reference link targets in `SKILL.md` are `skill://material-design-3-ui/references/<file>.md` URIs, so omp resolves them. The upstream `tests/validate_skill.py` scans for relative `references/*.md` links, so that check no longer matches, and the other upstream checks cover repository files that this pack does not carry.
  2. The frontmatter holds only `name` and `description`. The upstream `metadata` block carries the version and the date, and this library keeps both here instead.
