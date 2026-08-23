---
name: nushell-transform-structured-data
description: "Filter, reshape, and update Nushell lists, records, and tables without mutating the original value."
---

## When to use

Use this skill when you need to filter rows, update fields, reshape nested structures, or build new records/tables from existing data.

## Core commands

- `where <condition>` — filter rows or list items. The condition is a block or expression that evaluates to a boolean.
- `each { |item| ... }` — run a block for every item in a list/table, returning a list of results.
- `update <path> { <block> }` — replace a value at a cell-path and return a new record/table.
- `insert <path> <value>` — add a new key/column at a cell-path and return a new record/table.
- `upsert <path> <value>` — insert if missing, update if present.
- `sort-by <column>` — sort a table by one or more columns.
- `append`, `prepend`, `++` — combine lists or tables. `++` is the inline operator form.
- `merge` — combine two records/tables side-by-side (column-wise).
- `flatten` — collapse nested lists into a single list.
- `wrap <column>` — turn a list into a single-column table.
- `transpose` — swap rows and columns; also useful to turn a record into a two-column table.
- `items { |key, value| ... }` — iterate over key-value pairs of a record.
- `str trim` — trim whitespace across columns.
- `rename` — rename columns.

## Patterns

### Filter rows
```nu
ls | where size > 1kb
ls | where ($it.name | str ends-with ".rs")
[1 2 3 4 5] | where $it > 2
```

### Add or update a column
```nu
ls | upsert size_kb { $it.size / 1kb }
```

### Transform each row with a block
```nu
ls | each { |file| { name: $file.name, ext: ($file.name | path parse | get extension) } }
```

### Reshape a record into a table
```nu
{ apples: 543, bananas: 411 } | transpose fruit count
```

### Merge records
```nu
let first = { name: "Sam", rank: 10 }
$first | merge { title: "Mayor" }
```

### Flatten nested lists
```nu
[1 [2 3] 4 [5 6]] | flatten
```

### Sort and limit
```nu
ls | sort-by modified | first 5
```

## Tips

- Nushell values are immutable; every transform returns a new value. The original variable stays unchanged.
- `update`/`upsert`/`insert` accept a cell-path, so you can target nested keys: `update foo.bar { $in + 1 }`.
- Use `each` when the output shape differs per row; use `update`/`upsert` when you just need to add or modify a column in a table.
- `where` blocks can use `$it` (the current item) or a named closure parameter.
- For conditional updates, combine `where` with `update` or use `upsert` with a block that returns a value based on `$in`.
