---
name: decky-installable-release
description: Package and document Decky developer-mode installable ZIP releases
---

## Packaging

1. Build the frontend so `frontend/dist` exists.
2. Create one archive folder, for example `release/travelling-deck`.
3. Copy into it:
   - `backend/`, then move `backend/main.py` to root `main.py`.
   - `backend/sensors/` to root `sensors/`.
   - `frontend/dist/` to root `dist/`.
   - root `plugin.json`, `frontend/package.json`, and `README.md`.
4. Remove the now-empty backend directory.
5. Zip the folder itself from its parent:
   ```sh
   (cd release && zip -qr ../travelling-deck-${TAG}.zip travelling-deck)
   ```
   This preserves the required single top-level folder; do not zip its contents at archive root.
6. Verify the downloaded ZIP contains exactly one `*/plugin.json` with one slash, plus `travelling-deck/dist/index.js`, `travelling-deck/main.py`, `travelling-deck/sensors/__init__.py`, and `travelling-deck/package.json`.

## README installation and removal

Document release ZIP installation through Decky's Developer page using **Install Plugin from ZIP**. The Developer page has no uninstall action. Document removal through Quick Access Menu → Decky → Settings → Plugins → plugin row `⋯` → Uninstall. Keep manual deletion of `/home/deck/homebrew/plugins/travelling-deck` as a fallback only for source-directory installs.

## Release gate

Require a successful GitHub Actions run and the archive assertions above.
