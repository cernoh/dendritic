---
name: linux-companion-issue-pr-bootstrap
description: Bootstrap a private Linux companion project with clean-room guardrails and issue-linked PRs
---

1. Verify GitHub authentication and start from an empty local directory.
2. Initialize `main`, create the private GitHub repository, add `origin`, and push the base commit.
3. Read the upstream public documentation; extract capabilities, data sources, Linux constraints, and clean-room boundaries.
4. Create one GitHub issue per roadmap slice, each with acceptance criteria and a clear PR boundary.
5. Create a feature branch per issue. Add only the minimum working slice plus deterministic tests.
6. Open PRs with `Closes #N`, merge after checks pass, and verify both PR merge state and issue closure.
7. Keep explicit prohibitions in README/CONTRIBUTING: no proprietary code reuse/decompilation, game-memory reads, injection, file modification, or input automation.
