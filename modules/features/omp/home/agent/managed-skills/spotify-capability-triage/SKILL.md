---
name: spotify-capability-triage
description: Triage Spotify Jam or offline playback requests before implementation
---

# Spotify capability triage

Use when a feature request mentions Spotify Jams, offline playback, downloads, or cached audio.

1. Check the current official Spotify Web API documentation and reference.
2. Inspect the actual client backend and pinned dependency revision. Do not infer capability from Web API limitations alone when the product embeds a client protocol such as librespot.
3. Verify whether the requested operation has a documented public endpoint or an existing authorized client implementation.
4. For librespot specifically, inspect `AudioFile::open`, `Cache`, `AudioKeyManager`, `Session::connect`, and Dealer/session-update handling. Encrypted audio caching is not equivalent to offline playback when audio keys, metadata, or session authentication still require network access.
5. Treat Jam as unimplemented unless the backend has concrete lifecycle APIs and a tested protocol implementation. Do not invent endpoints.
6. A safe partial offline feature may use durable, bounded cache storage plus an explicit cache policy that prevents known cache misses from silently downloading. Document that this is not full offline playback unless keys and metadata are also available offline.
7. Do not put Spotify credentials, access tokens, or undocumented endpoints into GitHub Actions. Use Actions for build, test, artifact, and release gates only.
8. If blocked or partially blocked, create or update a GitHub issue describing:
   - the documented API gap,
   - links to official references,
   - backend source evidence and exact missing APIs,
   - the supported subset and deferred work,
   - the authorized protocol/entitlement details needed to proceed.
9. If Issues are disabled, enable them before creating the blocker issue.
10. When adding workflow files, prefer SSH push if HTTPS OAuth lacks the `workflow` scope; otherwise request the scope interactively.
11. Only implement unsupported full behavior after the authorized protocol and required key/metadata lifecycle are supplied.
