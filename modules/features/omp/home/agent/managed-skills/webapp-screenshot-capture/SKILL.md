---
name: webapp-screenshot-capture
description: "Use when capturing screenshots of a local web app for visual QA, demos, or pull requests"
---

## Procedure

1. Start the local app using its existing development or preview command. Do not add dependencies solely for screenshots.
2. Open the app in the browser automation tool at the local URL.
3. Wait for the page to finish loading and confirm the primary content is visible.
4. Capture one full-page screenshot at a desktop viewport and, when responsive behavior matters, one narrow mobile viewport.
5. Inspect the screenshot for broken layout, missing assets, unreadable text, clipping, and contrast problems.
6. Save screenshots only when they are needed as artifacts or PR evidence; otherwise return the captured image directly.
7. If Chromium fails to launch because system libraries are missing, report the exact missing library and use a mental/code review instead of claiming visual verification succeeded.

## Evidence

Report the URL, viewport size, screenshot path or artifact, and any visual issues found. Never claim a screenshot was captured if browser startup or navigation failed.
