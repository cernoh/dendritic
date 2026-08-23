---
name: nushell-aggregate-export-structured-data
description: "Summarize, group, and serialize Nushell structured data to common formats or disk."
---

## When to use

Use this skill when you need to compute summaries, group data, reduce lists to a single value, or save structured data back to a file for another tool.

## Core commands

### Aggregation

- `group-by <column> --to-table` — group rows into a table of `group` and `items` columns.
- `math sum`, `math avg`, `math min`, `math max`, `math stddev`, `math variance` — numeric aggregations.
- `reduce { |item, acc| ... }` — fold a list into a single value. Use `--fold` to set an initial accumulator.
- `any { |item| ... }` — true if at least one item matches.
- `all { |item| ... }` — true if every item matches.
- `length` — count items.
- `uniq`, `uniq-by` — remove duplicate rows or values.
- `count` — count occurrences, often used after a transform.

### Dataframes (large datasets)

- `polars open --eager <file>` — load a file into a Polars DataFrame (requires `nu_plugin_polars`).
- `polars group-by <col> | polars agg (...) | polars collect` — fast columnar aggregation.
- `polars sum`, `polars mean`, `polars sort-by`, `polars filter`, `polars join` — columnar operations.
- `polars store-ls` — list dataframes currently in memory.
- `plugin stop polars` — clear the dataframe cache.

### Export / serialization

- `save <path>` — write output to a file. Use `--raw` to keep it as text.
- `to json` — serialize to JSON.
- `to csv` — serialize to CSV.
- `to tsv` — serialize to TSV.
- `to nuon` — serialize to Nushell Object Notation (preserves Nushell types).
- `to yaml` — serialize to YAML.
- `to xml` — serialize to XML.

## Patterns

### Group and aggregate a table
```nu
open sales.csv | group-by region --to-table | update items { |g| $g.items.amount | math sum }
```

### Reduce a list
```nu
[1 2 3 4] | reduce { |item, acc| $acc + $item }        # sum
[1 2 3 4] | math sum                                    # same, faster
[2 3 4] | reduce --fold 1 { |item, acc| $acc * $item } # product
```

### Group with a dataframe
```nu
let df = polars open --eager sales.csv
$df | polars group-by region | polars agg (polars col amount | polars sum) | polars collect
```

### Export to JSON
```nu
open data.json | where active == true | to json | save active.json
```

### Export to CSV
```nu
ls | select name type size | to csv | save files.csv
```

### Export raw text
```nu
"hello" | save hello.txt --raw
```

## Tips

- Prefer `group-by --to-table` when you want to continue processing the grouped items with native table commands.
- For large files (millions of rows), use the Polars dataframe plugin instead of native row-based commands. It is orders of magnitude faster for group-by and join operations.
- `to json` and `to csv` produce strings. Pipe them into `save` to write to disk, or use them directly in scripts.
- `to nuon` is the best format for round-tripping Nushell values because it preserves types like dates, durations, and file sizes.
- Run `describe` on the result before saving to make sure the shape matches what the target format expects (e.g., `to csv` expects a table or list of records).
