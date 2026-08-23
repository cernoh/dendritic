---
name: nixpc-bootstrap
description: Provision the x86_64 nixpc Home Manager host remotely or locally with authenticated GitHub access and NVIDIA checks
---

## Procedure

1. Verify the target is x86_64, the configured user is `davr`, and `nix`, `git`, and `gh` are available.
2. If GitHub CLI authentication exists but Git clone fails, run `gh auth setup-git` on the host.
3. Confirm NVIDIA is active with `nvidia-smi` or the `nvidia` kernel module; stop with driver guidance if absent.
4. Ensure the repository bootstrap fetches `origin/main`, and evaluates `homeConfigurations.nixpc` with the davr identity and shared `../home.nix` import.
5. Enable flakes through `NIX_CONFIG` if unset.
6. Evaluate MangoWM with `nix eval --json`; do not use `--raw` for a Boolean.
7. Build the repository-pinned `homeConfigurations.nixpc.activationPackage` with `--print-out-paths`.
8. Run the generated `$activation/activate` script with no arguments. This Home Manager revision rejects `--backup-extension`.
9. Validate shell syntax with `bash -n` before committing.
