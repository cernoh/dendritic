---
name: nushell-navigate-structured-data
description: "Access and inspect values inside Nushell lists, records, tables, and nested combinations."
---

## When to use

Use this skill after data is loaded and you need to read values, select subsets, or understand the shape of structured data in a Nushell pipeline.

## Core commands

- `describe` — show the type of the pipeline value. Always run this first on unknown data.
- `get <path>` — return the value at a cell-path. Use for columns, indices, nested keys, or dynamic paths stored in a variable.
- `select <path> ...` — return a new record/list/table containing only the requested structure. Differs from `get` because it preserves the container (table row numbers, column names, etc.).
- `$value.<path>` — cell-path literal syntax. `record.key`, `list.3`, `table.column.row`, `data.temps.2.1`.
- `$.key` — cell-path literal when you need to assign a path to a variable (`let cp = $.name.0`).
- `first`, `last`, `skip`, `drop` — pull subsets of rows or list items by position.
- `is-empty`, `length` — check emptiness or count items in a list/table.
- `enumerate` — add an `index`/`item` pair to a list, useful when the original index matters after filtering.

## Patterns

### Inspect shape
```nu
ls | describe
open data.json | describe
```

### Cell-path literals
```nu
let data = [[date temps condition]; [now [1 2 3] 'sunny']]
$data.temps.0.2   # third temp of first day
$data.condition.1 # condition of second row
```

### `get` vs `select` on a table
```nu
$data | get 1        # returns a record
$data | select 1      # returns a single-row table with column names
$data | get condition # returns a list
$data | select condition # returns a single-column table
```

### Dynamic navigation
```nu
let col = "size"
ls | get $col
let index = 2
[foo bar baz] | get $index
```

### Nested records
```nu
let r = { name: "A", address: { city: "Oslo", zip: "0001" } }
$r.address.city
$r | get address.zip
```

## Tips

- A table is a list of records, so any list command works on tables. The reverse is not always true.
- `get` returns the raw value; `select` returns a wrapped version. Use `get` when feeding a value into the next command, `select` when you want the result to still display as a table.
- Use `enumerate` before `select`/`skip` if you need to remember original row indices.
- For keys with spaces, use `$record."key name"` or `$record | get "key name"`.
