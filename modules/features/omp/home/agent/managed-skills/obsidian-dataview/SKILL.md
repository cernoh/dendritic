---
name: obsidian-dataview
description: "Dataview plugin for Obsidian — DQL query language, DataviewJS API, frontmatter/inline fields, common query patterns, and file metadata"
---

# Dataview for Obsidian

Query your Obsidian vault as a database. Provides a pipeline-based query language (DQL) and JavaScript API for filtering, sorting, and extracting data from Markdown pages.

## Data Sources

Dataview pulls data from:
1. **YAML frontmatter** — `---` block at top of file
2. **Inline fields** — `Key:: Value` syntax anywhere in markdown

### Frontmatter Example
```yaml
---
alias: "document"
last-reviewed: 2021-08-17
rating: 8
tags: [book, fiction]
---
```

### Inline Fields Example
```markdown
Basic Field:: Value
**Bold Field**:: Nice!
[field:: inline field]
```

## Query Modes

### 1. Dataview Query Language (DQL)

Pipeline-based, SQL-like syntax:

```dataview
TABLE file.name AS "File", rating AS "Rating" 
FROM #book
SORT rating DESC
```

**Common queries:**

```dataview
# Table with specific fields
TABLE time-played, length, rating
FROM "games"
SORT rating DESC

# List from tag
LIST FROM #game/moba OR #game/crpg

# Tasks from folder
TASK FROM #projects/active

# Filter by date
LIST FROM #book
WHERE time-read.year = 2021
```

**DQL clauses:**
- `TABLE field1, field2` — show fields as columns
- `LIST` — show file names
- `TASK` — show tasks
- `CALENDAR date_field` — show as calendar
- `FROM source` — folder, tag, or link filter
- `WHERE condition` — filter rows
- `SORT field ASC/DESC` — sort results
- `GROUP BY field` — group results
- `FLATTEN field AS name` — expand arrays

### 2. Inline Expressions

Embed DQL in markdown, evaluated in preview:

```markdown
We are on page `= this.file.name`.
Total books: `= length(this.file.inlinks)`.
```

### 3. DataviewJS (JavaScript API)

Full JavaScript access to Dataview index:

```dataviewjs
for (let group of dv.pages("#book")
    .where(p => p["time-read"].year == 2021)
    .groupBy(p => p.genre)) {
    dv.header(3, group.key);
    dv.table(["Name", "Rating"],
        group.rows
            .sort(k => k.rating, 'desc')
            .map(k => [k.file.link, k.rating]));
}
```

**DataviewJS helpers:**
- `dv.pages(selector)` — get pages
- `dv.table(headers, rows)` — render table
- `dv.list(items)` — render list
- `dv.taskList(tasks)` — render tasks
- `dv.header(level, text)` — add heading
- `dv.paragraph(text)` — add paragraph
- `dv.current()` — current page
- `dv.page(path)` — specific page

### 4. Inline JS Expressions

JavaScript inline:

```markdown
Last modified: `$= dv.current().file.mtime`.
```

## Common Patterns

### Grouped table
```dataview
TABLE rows.file.link AS "Files"
FROM #book
GROUP BY genre
```

### Filter by frontmatter
```dataview
LIST
FROM "books"
WHERE rating >= 4 AND status = "read"
```

### Tasks with metadata
```dataview
TASK
FROM "projects"
WHERE !completed
SORT file.ctime ASC
```

### Count files by tag
```dataview
TABLE length(rows) AS "Count"
FROM #project
GROUP BY file.tags
```

## File Metadata

Every file has implicit fields:
- `file.name` — file name
- `file.path` — full path
- `file.link` — wikilink to file
- `file.tags` — all tags
- `file.outlinks` — outgoing links
- `file.inlinks` — incoming links
- `file.ctime` — creation time
- `file.mtime` — modification time
- `file.tasks` — all tasks in file
- `file.lists` — all list items
- `file.frontmatter` — raw frontmatter object

## Selectors

- `"folder"` — files in folder
- `#tag` — files with tag
- `#tag/subtag` — nested tags
- `[["page"]]` — files linking to page
- `[[page]]` — files linked from page
- Combine with `AND`, `OR`, `NOT`

## Tips

- Use `SORT file.mtime DESC` for recently modified
- `WHERE field` filters out files without the field
- `FLATTEN` expands arrays into multiple rows
- `GROUP BY` creates `key` and `rows` for each group
- DataviewJS is more powerful but less sandboxed than DQL

## Security Note

DataviewJS queries run with full plugin access and can modify files. Regular DQL queries are sandboxed. Only run JavaScript from trusted sources.
