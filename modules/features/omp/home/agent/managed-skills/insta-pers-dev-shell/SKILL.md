---
name: insta-pers-dev-shell
description: Use when setting up or verifying the insta-pers development environment.
---

## insta-pers development shell

- Enter the repo and run `direnv allow` to load `.envrc`.
- The shell is defined in `flake.nix` and exposes Node.js through `devShells.<system>.default`.
- Direct verification: `nix develop .#default --command bash -lc 'node --version && npm --version'`.
- Start the Vite page with `npm install` followed by `npm run dev`.
