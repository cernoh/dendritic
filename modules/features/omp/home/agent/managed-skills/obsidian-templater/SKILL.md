---
name: obsidian-templater
description: "Templater plugin for Obsidian — template syntax, core modules (tp.file, tp.date, tp.system, tp.web, tp.frontmatter, tp.config), JavaScript execution, and common patterns"
---

# Templater for Obsidian

Templater is a template language for Obsidian that lets you insert variables and function results into notes, and execute JavaScript code.

## Syntax

Template code is wrapped in `<% %>` tags:
- `<% expression %>` — outputs the result
- `<%* statement %>` — executes code without output

## Core Modules

### tp.file — File operations
- `tp.file.title` — current file name
- `tp.file.creation_date(format?)` — file creation date
- `tp.file.last_modified_date(format?)` — last modified date
- `tp.file.move(new_path)` — move/rename file
- `tp.file.content` — file content
- `tp.file.cursor(position?)` — place cursor after template

### tp.date — Date functions
- `tp.date.now(format?, offset?, reference?)` — current date with optional offset
- `tp.date.tomorrow(format?)` — tomorrow's date
- `tp.date.yesterday(format?)` — yesterday's date
- Format uses moment.js syntax (e.g., "YYYY-MM-DD", "dddd Do MMMM YYYY")

### tp.system — System interactions
- `tp.system.prompt(message, default_value)` — prompt user for input
- `tp.system.suggester(items, values)` — show selection menu

### tp.web — Web requests
- `tp.web.daily_quote()` — random daily quote
- `tp.web.request(url, options?)` — make HTTP request

### tp.frontmatter — Access frontmatter
- `tp.frontmatter.key` — access any frontmatter field

### tp.config — Template configuration
- `tp.config.target_file` — file being templated
- `tp.config.run_mode` — how template was triggered

## Example Template

```markdown
---
creation: <% tp.file.creation_date() %>
modified: <% tp.file.last_modified_date("YYYY-MM-DD") %>
tags: [note]
---

# <% tp.file.title %>

Created: <% tp.date.now("YYYY-MM-DD") %>

<%* if (tp.frontmatter.type === "meeting") { *%>
## Meeting Notes
<%* } else { *%>
## General Notes
<%* } *%>
```

## Execution Modes

1. **Insert mode** — template inserted into current file
2. **Create mode** — new file created from template
3. **Trigger on file creation** — auto-apply when new file created (with auto-template-trigger plugin)

## JavaScript Execution

Use `<%* %>` for statements that shouldn't output:
```
<%* const tags = tp.frontmatter.tags || []; %>
<%* if (tags.includes("project")) { *%>
This is a project note.
<%* } *%>
```

## User Scripts

Place JavaScript files in `Scripts/` folder, call them as functions:
```
<% tp.user.myScript(param) %>
```

## Common Patterns

### Date-based notes
```
<% tp.date.now("YYYY-MM-DD") %>
<% tp.date.now("YYYY-[W]WW") %>
```

### Conditional content
```
<%* if (tp.file.title.includes("Meeting")) { *%>
## Attendees
## Action Items
<%* } *%>
```

### User prompts
```
Title: <% await tp.system.prompt("Enter title") %>
Type: <% await tp.system.suggester(["Note", "Meeting", "Project"], ["note", "meeting", "project"]) %>
```

### Frontmatter manipulation
```
---
<%* if (!tp.frontmatter.created) { *%>
created: <% tp.file.creation_date() %>
<%* } *%>
---
```

## Security Warning

Templater can execute arbitrary JavaScript and system commands. Only run code from trusted sources.
