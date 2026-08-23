---
name: omp-flake-version-update
description: "Update the oh-my-pi (omp) binary version in the Nix flake — fetch latest release from GitHub API, convert SHA256 digests to SRI format, update flake.nix, verify with nix build"
---

# Update OMP version in omp-flake

## When to use
User asks to update the oh-my-pi / omp binary version in the Nix flake.

## Procedure

1. **Find latest fully-published release** — query the GitHub API, not the atom feed alone (a tag may appear before assets finish uploading):
   ```
   curl -sL https://api.github.com/repos/can1357/oh-my-pi/releases/latest
   ```
   Extract `tag_name` and each asset's `name` + `digest` field.

2. **Verify all 4 platform assets exist**: `omp-linux-x64`, `omp-linux-arm64`, `omp-darwin-x64`, `omp-darwin-arm64`. If any are missing, the release isn't ready — fall back to the previous tag.

3. **Convert hex digests to Nix SRI format** (the API provides `sha256:<hex>`, Nix wants `sha256-<base64>`):
   ```python
   import base64
   b64 = base64.b64encode(bytes.fromhex(hex_digest)).decode()
   sri = f"sha256-{b64}"
   ```

4. **Edit `flake.nix`**: update the 4 `url` lines (version tag in URL path) and the 4 `sha256` lines in the `sources` attrset, plus the `version` string in `mkDerivation`.

5. **Verify**:
   ```bash
   nix build .#
   ./result/bin/omp --version
   ```

## Notes
- A Windows binary (`omp-windows-x64.exe`) exists in releases but the flake doesn't target Windows — ignore it.
- If `nix build` fails with a hash mismatch, the API digest was stale; re-fetch and retry.
