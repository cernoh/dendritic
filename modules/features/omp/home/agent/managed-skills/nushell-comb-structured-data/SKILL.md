---
name: nushell-comb-structured-data
description: "Use Nushell to quickly explore, aggregate, clean, and export JSON or other structured data after loading it."
---

# Nushell structured-data combing

Use this skill when you need to quickly understand, search, summarize, clean, or export JSON, CSV, YAML, API responses, logs, or other structured data in Nushell. It is the workflow glue between loading, navigation, and transformation—not a replacement for those skills.

## Core workflow

Start broad, then narrow:

```nu
let data = open response.json
$data | describe
$data | first 5
```

For an unknown nested payload, inspect one layer at a time:

```nu
$data | describe
$data | get results | describe
$data | get results | first 3
$data | get results | select id name status
```

Use `table`, `view`, or `debug` when output is too wide or ambiguous:

```nu
$data | table
$data | debug
```

A jq-like exploration pattern is: load → `describe` → `get`/`select` → `where` → reshape → aggregate → export.

## Search and filter

```nu
$data | where status == 'active'
$data | where ($it.name | str contains 'error')
$data | where ($it.tags? | is-not-empty)
```

For nested or optional fields, use `get`/cell paths and null-safe access where available:

```nu
$data | where ($it.user?.team? == 'platform')
$data | get results | where ($it.metadata?.severity? == 'high')
```

Keep only useful columns before inspecting or aggregating:

```nu
$data | select id created_at amount
$data | reject debug_payload internal_notes
```

## Aggregation

Group rows, then inspect each group:

```nu
$data | group-by status
$data | group-by status | transpose status rows
```

Count categories:

```nu
$data | get status | uniq -c
$data | group-by status | items { |status, rows| { status: $status, count: ($rows | length) } }
```

Summarize numeric fields:

```nu
$data | get amount | math sum
$data | get amount | math avg
$data | get amount | math min
$data | get amount | math max
$data | histogram amount
```

Per-group summaries:

```nu
$data
| group-by category
| items { |category, rows|
    {
      category: $category,
      count: ($rows | length),
      total: ($rows | get amount | math sum)
    }
  }
```

Sort after computing summaries:

```nu
... | sort-by total --reverse | first 10
```

If values may be null, clean them before math commands:

```nu
$data | get amount | compact | math sum
```

## Cleanup and normalization

Remove null-like or unwanted records before analysis:

```nu
$data | compact
$data | reject null_field obsolete_field
$data | where ($it.amount? != null)
```

Normalize fields without mutating the original value:

```nu
$data
| upsert name { $in | str trim }
| upsert amount { $in | into float }
```

Flatten nested collections only when the row boundary is no longer useful:

```nu
$data | get items | flatten
```

Use `enumerate` before filtering when original positions matter:

```nu
$data | enumerate | where item.status == 'failed'
```

## Export and handoff

Choose the output format for the next consumer:

```nu
$data | to json
$data | to json --indent 2
$data | to nuon
$data | to csv
$data | save summary.csv
```

Write only the final shaped value, not exploratory output:

```nu
$data
| where status == 'active'
| select id name
| to json --indent 2
| save active-users.json
```

For a quick one-off handoff, pipe to an external command only after shaping the data:

```nu
$data | to json -r | ^jq '.items | length'
```

## Failure modes

- Unknown shape: run `describe` before `get`, `select`, or `where`.
- Record vs table confusion: use `get` for a raw nested value; use `select` to preserve table display.
- Missing fields: use optional access (`field?`) or filter before arithmetic.
- Math errors: `compact`, convert types, and verify with `describe`.
- Huge payloads: select or filter early; inspect `first`/`last` rather than printing everything.
- Export surprises: check the final value with `describe` and a small sample before `save`.

## Related skills

- `nushell-load-structured-data` — load files, HTTP responses, databases, and raw strings.
- `nushell-navigate-structured-data` — access nested values with `get`, `select`, and cell paths.
- `nushell-transform-structured-data` — filter, reshape, update, sort, merge, and flatten values.
