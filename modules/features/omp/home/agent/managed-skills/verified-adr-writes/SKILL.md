---
name: verified-adr-writes
description: Use when recording ADR decisions in travelling-deck documentation
---

1. Read the target ADR with a plain path or :raw for inspection.
2. Rewrite the full file using `write` with the plain file path; never append `:raw` to a write target.
3. Read the file back immediately with `:raw`.
4. Confirm the newly resolved decision is present before continuing the grilling session.
