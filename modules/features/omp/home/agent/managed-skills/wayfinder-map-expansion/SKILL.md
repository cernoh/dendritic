---
name: wayfinder-map-expansion
description: Expand a GitHub wayfinder map with sharp labeled decision tickets and correct fog-of-war bookkeeping
---

Use the canonical map issue as the low-resolution source. Create only questions that are precise enough to ticket now; leave unresolved broader areas in Not yet specified. Label every child with wayfinder:<type>. Create tickets first, then wire native GitHub blocking dependencies in a second pass using blocker database IDs. Update the map so graduated fog is removed and only genuinely un-ticketable handoff fog remains. Verify frontier queries surface every open, labeled, unblocked, unclaimed ticket.
