---
name: obsidian-nodian
description: "Nodian plugin for Obsidian — bidirectional YAML frontmatter relations, relation pairs with tag-based matching, auto-sync backlinks, and common use cases"
---

# Nodian for Obsidian

Nodian automatically syncs bidirectional relations in YAML frontmatter. When you add a wikilink to a property in one file, the plugin writes a backlink in the target file's corresponding property.

## Core Concept

Define relation pairs in Settings → Nodian → Relation pairs. Each pair has:
- Property A ↔ Property B
- Tag A ↔ Tag B (required, prevents wrong-target sync)

## How It Works

When you add a wikilink to a paired property, Nodian:
1. Checks if the source file has the matching property AND tag
2. Writes a backlink in the target file's corresponding property
3. Removes the backlink when you delete the link

## Example

**Person.md**
```yaml
---
tags: [Person]
Mail: "[[hello@example]]"
---
```

**hello@example.md** (auto-generated)
```yaml
---
tags: [Mail]
Person: "[[Alice]]"
---
```

## Setup

### Step 1: Add a wikilink to a property
```yaml
---
tags: [Person]
Mail: "[[hello@example]]"
---
```

### Step 2: Configure the relation
Right-click the property name → "Configure bidirectional relation"
- Set counterpart property (e.g., `Person`)
- Set tags for both sides
- Press Save

### Step 3: Run full sync (for existing vaults)
- Click sync icon in left ribbon, OR
- Settings → Nodian → "Run full sync", OR
- Command Palette → "Sync all bidirectional relations"

## Features

- **Auto sync** — add/remove links, other side updates instantly
- **Relation pairs** — define which properties are paired
- **Tag-based matching** — sync only fires when both property and tag match
- **Display names** — optionally use `title` property as display text in backlinks
- **New file support** — creating a file from wikilink auto-adds tags and backlinks
- **Self-relations** — property can pair with itself (e.g., `Related ↔ Related`)
- **Multiple links** — property can hold multiple wikilinks

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| Auto sync | ON | Sync backlinks automatically when editing |
| Use title as display name | OFF | Use `title` property as display text in backlinks |
| Show ribbon sync button | ON | Show button in left ribbon for full sync |
| Debug mode | OFF | Log detailed info to developer console |

## Common Relation Pairs

**Music vault:**
- Artist ↔ Release
- Artist ↔ Tracks
- Composer ↔ Works
- Label ↔ Releases

**CRM vault:**
- Mail ↔ Person
- Mail ↔ Domain
- Service ↔ Account

## Important Notes

- **Tags are required** — every relation pair needs Tag A and Tag B
- **Back up before first use** — plugin modifies YAML frontmatter directly
- **Deleting a file** doesn't remove backlinks pointing to it (by design)
- **Renaming a file** is handled by Obsidian's built-in link updater
- **Duplicate pairs** are redundant — one pair covers both directions
- **Duplicate basenames** (same name in different folders) may cause incorrect sync
- **System properties** (`title`, `aliases`, `tags`, `cssclasses`) cannot be used as relation properties

## Display Names

Enable "Use title as display name" in Settings. Backlinks will use:
```
[[my-artist-id|Some Artist Name]]
```
Uses the `title` property from source file's frontmatter. Run full sync after changing this setting.

## Mobile Support

On phones, Nodian uses card UI:
- Tap property icon → "Edit bidirectional relation"
- **+** button opens add screen with autocomplete
- Settings → Relation pairs shows cards with edit/delete
