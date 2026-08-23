---
name: stremio-kai-linux-overlay
description: Package Stremio-Kai portable mpv configuration for Linux in a Nix flake
---

Use the existing validated procedure: pin portable_config-only source, package with an overlay, copy through Home Manager activation into writable ~/.config/mpv, chmod recursively u+w, and verify syntax/evaluation/build. When a fix appears uncommitted, check HEAD and the remote branch before retrying commit; it may already be included in an earlier commit.
