---
name: wayfinder-hitl-ticket-resolution
description: "Close out a wayfinder HITL (wayfinder:grilling) ticket end to end: measure first, run the grill_form rounds, publish the long-form deliverable on a research branch, scribe the resolution comment plus any cross-ticket erratum, splice the map by anchor, graduate fog, and verify the frontier."
---

Companion to `skill://wayfinder-ticket-evidence-grounding` (measure before the round) and `skill://wayfinder-resolve-ticket` (research tickets). This is the close-out path for a ticket labelled `wayfinder:grilling`, where the deliverable is a decision record rather than a measurement.

## Order of work

1. **Orient and claim.** Ticket + map bodies, `blocked_by` (open blockers only), then `~/.omp/agent/scripts/wayfinder-frontier.sh <owner>/<repo>`, then `gh issue edit <n> --add-assignee @me`. Read the gating tickets' resolutions — "already decided" lines constrain the round more than the ticket text.
2. **Measure with subagents, two slices, one batch.** One scout for the components the ticket names, one for the adjacent families the ticket forgot (a ticket that says "every hand-rolled thing" and then enumerates nine items will have left four families out). Brief each scout with: the exact file list, the output shape (declarations with line numbers, behaviour inventory with `file:line`, call sites split PRODUCTION vs `@Preview`, and the three hardest-to-reproduce behaviours), no edits, no gradle, and a `@Preview`-aware split — that split is usually decisive.
3. **Verify the load-bearing numbers yourself.** A scout's headline count survives a normal read but not a recount: `git grep -o -F 'Name(' | wc -l` includes declarations, commented-out mentions, and preview-only sites. State the counting basis in the deliverable ("154 production sites in 20 files; 156 textual occurrences, two commented out").
4. **Run the rounds.** One decision per question, recommendation first, `file:line` in every body, 3-4 choices. A round that only restates the ticket is a rubber stamp. After each submit, recompute the frontier. Stop when no *design* question remains; a table-acceptance round is legitimate as the last round, with the artifact linked in the body.
5. **Publish the deliverable.** Long-form table on a research branch (`research/<ticket>-<slug>`), never in `main`: fetch origin, branch, write, commit, push. Then `render_html` it with `open: true` and put the rendered path in the acceptance round and the resolution.
   - Fetch the pinned artifact while you are there, so the table's Material-side claims are yours and not inherited: `curl -fsS -o m3.aar https://dl.google.com/dl/android/maven2/<group-path>/<artifact>/<version>/<artifact>-<version>.aar`, plus the `-sources.jar` for readable opt-in annotations.
6. **Record.** Resolution comment through `issue-scribe` with a brief that names the repo, the issue number, and the pointer set — a scribe posts only what the brief names, so put every intended target in the brief or say explicitly "one comment on issue N". Then `gh issue close <n>` (prints nothing; verify with `--json state,stateReason`).
7. **Map edit, anchor-spliced.** `gh issue view <map> --json body -q .body > /tmp/map.md`, edit by anchor with the `edit` tool, `gh issue edit <map> --body-file`, refetch, `diff` — only GitHub's one trailing newline may differ. Keep 3+ newline runs and the bullet style of the surrounding list.
8. **Graduate fog.** Sharp new question → child ticket with the `wayfinder:*` label plus the `sub_issues` REST attach. Unsharp → one line in `## Not yet specified`. Sleep ~9 s before the frontier query: a fresh dependency edge takes that long to appear.
9. **Close out.** `wayfinder_view` for the URL and solved/left counts; state the next frontier ticket and whether it is HITL. Return the checkout to `main`. Work on a research branch is not gitignored, so say whether a DOX pass applies instead of skipping it silently.

## Traps that cost real cycles here

- **A system advisory that contradicts a closed ticket is usually right — verify, then correct both places.** Confirm with a read of the enclosing function and a grep for its callers, fix the deliverable (new commit, so the SHA already quoted stays valid), and post the erratum on the *other* ticket, not only on yours. Here: a call site that a closed plan called a `@Preview` sits in a production composable with four callers, which changes the tier's scope.
- **Journal-style "as measured" rows age badly.** Label the counting basis, not just the number.
- **Do not re-run a settled sub-decision as a question**; put it in the deliverable's carrier column instead.
- `javap` needs a JDK: `nix shell nixpkgs#jdk21 -c javap -v -p -cp classes.jar <fqcn>`. Opt-in markers land in `RuntimeInvisibleAnnotations`; print declaration context with an awk ring buffer, since a bare grep of the output loses which member the annotation belongs to.
- Two scribes in one batch coordinate with each other and will refuse to duplicate a comment; tell them up front which issue owns which text.

## Reference: material3-android 1.4.0 opt-in verdicts (BOM 2026.05.01)

Verified with javap on the compiled jar; re-verify before quoting on another line.

- **No marker (stable):** `ListItem`, `Card`, `AlertDialog(confirmButton = …)`, `SegmentedButton` with `SingleChoiceSegmentedButtonRow`/`MultiChoiceSegmentedButtonRow`, `CircularProgressIndicator`/`LinearProgressIndicator` including the track + `gapSize` overloads, the state-taking `NavigationSuiteScaffold` overloads (the older ones are deprecated).
- **`ExperimentalMaterial3Api` (public marker, usable):** `SearchBar`, `DockedSearchBar`, `TopSearchBar`, `ExpandedFullScreenSearchBar`, `rememberSearchBarState`, `ModalBottomSheet`, `rememberModalBottomSheetState`, `BasicAlertDialog`, the content-slot `AlertDialog`.
- **Absent (tokens classes only):** `ButtonGroup`, `SplitButton`, `FloatingActionButtonMenu`, `LoadingIndicator`, `HorizontalFloatingToolbar`, `ToggleButton`, `MaterialShapes`.
- `ModalBottomSheet` takes `sheetGesturesEnabled`, a nullable `dragHandle`, `shape` and `contentWindowInsets` (default `BottomSheetDefaults.windowInsets`) — so hand-rolled drag pills and navigation-bar spacers are replaced by parameters and insets, not ported.
