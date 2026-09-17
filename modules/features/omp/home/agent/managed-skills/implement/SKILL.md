---
name: implement
description: "Implement one ticket or spec, then check the result against every acceptance criterion and report the checks you ran."
disable-model-invocation: true
---

Implement the work described by the spec or the ticket.

1. Read the spec or the ticket, plus every decision it links. Read the repository files the work touches before you write anything.
2. Work the ticket at the seams the spec agreed, and prefer a test at the highest seam the work has.
3. Run the checks as you go: the type check and the tests for the file you just changed. Run the full suite once at the end.
4. Check the result against every acceptance criterion of the ticket, and state plainly which ones hold and which ones you could not verify.
5. Commit to the current branch.
6. When the ticket came from a wayfinder map or a spec issue, comment the result there, then close the ticket. Refresh the map view with the `wayfinder_view` tool.
