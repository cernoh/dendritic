---
name: nix-tauri-workspace-verification
description: Verify a Nix-based Tauri Rust workspace and catch missing members or native build regressions
---

1. Keep `flake.nix` and `flake.lock` committed; provide Node 22, Rust, cargo-tauri, pkg-config, GTK3, WebKitGTK 4.1, libsoup 3, librsvg, and required GLib tooling in the devShell.
2. Make every Rust crate a member of the root workspace before using `version.workspace` or `edition.workspace` in child manifests.
3. Run `nix develop --command npm run check` for browser/domain tests.
4. Run `nix develop --command cargo test --workspace` so Tauri, platform core, and data crates compile together.
5. Run `nix flake check` to validate the pinned shell.
6. Fix compile errors at the source; common examples include explicit `parse::<SocketAddr>()` type annotations and matching the binary's library crate name.
7. Extend CI to run the same Nix-wrapped npm and Cargo commands; otherwise Rust regressions can land unnoticed.
