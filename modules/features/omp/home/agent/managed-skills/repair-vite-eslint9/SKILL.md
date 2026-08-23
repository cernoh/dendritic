---
name: repair-vite-eslint9
description: Repair ESLint 9 dependency and configuration failures in this Vite React repo
---

Run npm run lint. If ESLint crashes loading a rule, update typescript-eslint to ^8.66.0 and eslint-plugin-react-hooks to ^5.2.0. Replace empty interfaces with type aliases and use ESM imports instead of require() in TypeScript config files. Re-run npm run lint and npm run build; allow existing warnings but no errors.
