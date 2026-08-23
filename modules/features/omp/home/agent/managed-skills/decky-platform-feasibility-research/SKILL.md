---
name: decky-platform-feasibility-research
description: Research whether Decky Loader can satisfy plugin platform requirements before implementation
---

## Procedure

1. Read all project ADRs and context/glossary files before researching APIs.
2. Map each requirement to one of: confirmed by public Decky API, conditional on SteamOS/runtime behavior, or unverified platform gap.
3. Prefer primary sources: Decky Loader, decky-frontend-lib, plugin template, loader API, Linux kernel/IIO documentation, and relevant SteamOS sources.
4. Use Scrapling MCP for official web pages when ordinary reads are insufficient.
5. Explicitly test or flag assumptions about fullscreen compositor layering, input pass-through, global controller shortcuts, and sensor exposure; never infer support from a normal plugin panel.
6. Write a requirement matrix, concrete architecture, limitations, compatibility test matrix, and go/no-go gates to `.planning/IMPLEMENTATION.md`.
7. Read the written file back immediately to verify persistence and report only evidence-backed conclusions.
