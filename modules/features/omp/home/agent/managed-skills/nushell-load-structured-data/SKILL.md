---
name: nushell-load-structured-data
description: "Load structured data into Nushell pipelines from files, strings, databases, web APIs, and external sources."
---

## When to use

Use this skill when you need to bring data into Nushell so it can be inspected, filtered, transformed, or exported. The target may be a file on disk, a web API, a command output, a database, or raw text that needs parsing.

## Core commands

- `open <path>` — multi-tool loader. Auto-detects format by extension: `csv`, `json`, `yaml`, `toml`, `xml`, `xlsx`, `ods`, `ini`, `ssv`, `tsv`, `nuon`, `url`, `vcf`, `eml`, `ics`, and SQLite databases. Use `--raw` to keep the file as one string.
- `http get <url>` — fetch a URL and return the body as a string. Pipe into `from <format>` for structured responses (`http get ... | from json`).
- `http post <url> <body>` — send a POST request. Use `--content-type` to set the request type. Pipe the response into `from json`/`from csv` as needed.
- `from <format>` — parse a string into structured data when the file extension is wrong or missing. Examples: `from json`, `from csv`, `from toml`, `from yaml`, `from xml`, `from ssv`, `from tsv`.
- `query db <sql>` — run SQL against an SQLite database loaded with `open foo.db`.
- `lines` — split a multi-line string into a list of strings.
- `split column <delim> [col1 col2 ...]` — split each line into a table by a delimiter. Great for log or pipe-separated text.
- `str trim` — trim whitespace from strings, usually after `split column`.
- `parse <pattern>` — parse strings with a regex-like pattern when `split column` is not enough.
- `from nuon` — parse Nushell Object Notation, a strict superset of JSON that preserves Nushell types.

## Patterns

### Load a file and inspect its shape
```nu
open data.json | describe
open data.csv | first 5
```

### Fetch structured data from an API
```nu
http get https://api.example.com/data | from json
http get https://api.example.com/users.csv | from csv
```

### POST to an API and read the JSON response
```nu
http post https://api.example.com/search '{"q": "nushell"}' --content-type application/json | from json
```

### File has wrong extension
```nu
open Cargo.lock --raw | from toml
```

### Parse pipe-delimited text into a table
```nu
open people.txt | lines | split column "|" first_name last_name job | str trim
```

### Query SQLite
```nu
open app.db | query db "select * from users where active = 1"
open app.db | get users | first 10
```

### Convert CSV/TSV/JSON lines
```nu
open data.tsv | from tsv
"{\"a\":1}" | from json
```

## Tips

- `open` uses `from <format>` under the hood by matching the file extension. You can extend it by defining your own `from ...` custom command.
- For web APIs, `http get` is the first step; pipe the response to `from json`/`from csv`/`from xml` to turn it into structured data.
- SQLite is auto-detected regardless of extension. Use `get <table>` to pull a table, or `query db` for SQL.
- If the source is raw text, decide first: is it line-oriented (`lines` + `split column`/`parse`), or is it a known format in a string (`from <format>`)?
- Always `describe` after loading to confirm the structure (table, record, list, or nested mix) before chaining `get`/`select`/`where`.
