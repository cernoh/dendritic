---
name: travelling-deck-manual-install
description: Install the travelling-deck Decky plugin manually on Steam Deck
---

# Manual install

1. Install Decky Loader.
2. Enable Developer Mode in Decky settings.
3. Build the frontend on the Deck:

```sh
cd frontend
npm ci
npm run build
cd ..
```

4. Copy the repository to `/home/deck/homebrew/plugins/travelling-deck/`.
5. Restart the Decky plugin loader.
6. Open the Decky menu and select Travelling Deck.

Decky loads the panel from generated `frontend/dist/`. Do not omit the build step. Remove the plugin directory to uninstall.
