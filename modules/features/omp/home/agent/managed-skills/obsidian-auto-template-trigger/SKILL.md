---
name: obsidian-auto-template-trigger
description: "Auto Template Trigger plugin for Obsidian — auto-apply templates on note creation, folder-specific templates, template selector behavior"
---

# Auto Template Trigger for Obsidian

Automatically prompts for or applies templates when creating new notes. Depends on the core Templates plugin.

## Behavior

- **Single template** → automatically applied
- **Multiple templates** → template selector appears
- **Folder-specific templates** → assigned template auto-applies to files in that folder

## Settings

Assign templates to folders:
- Most specific folder path takes precedence
- Root folder (`/`) applies to all new files unless overridden
- "Disable prompt" option → only use folder-specific templates, never show selector

## Example Setup

1. Enable core Templates plugin, set templates folder (e.g., `Templates/`)
2. Create templates in that folder
3. Auto Template Trigger settings:
   - `/Projects` → "Project Note" template
   - `/Meetings` → "Meeting Note" template
   - `/` → "Default Note" template

## Folder Precedence

```
/Projects/Active/my-note.md  → uses "Project Note" template
/Projects/my-note.md         → uses "Project Note" template (if /Projects assigned)
/my-note.md                  → uses "Default Note" template (from /)
```

## Limitations

- Depends on core Templates plugin (not Templater)
- May not work well with Templater or daily notes plugins
- Templates must be in the folder specified in core Templates settings

## Use Case

Eliminates manual template triggering, especially useful on mobile where accessing commands is cumbersome.
