---
name: nix-android-tizen-flake
description: Create Nix flake with adb/fastboot/scrcpy and Tizen sdb shim for Galaxy Watch
---

# Nix Android + Tizen Flake

Use when creating/verifying a Nix dev flake for Android (adb/fastboot/scrcpy) and Tizen Watch Active (sdb/Odin).

## Pattern

```nix
{
  description = "Android ADB dev environment";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    systems = ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: import nixpkgs { inherit system; config.allowUnfree = false; };
  in {
    packages = forAllSystems (system: let pkgs = pkgsFor system; in {
      sdb-shim = pkgs.writeShellScriptBin "sdb" ''
        candidates=("$HOME/tizen-studio/tools/sdb" "$HOME/Tizen-Studio/tools/sdb" "/opt/tizen-studio/tools/sdb" "''${TIZEN_SDK:-}/tools/sdb")
        for c in "''${candidates[@]}"; do [ -x "$c" ] && exec "$c" "$@"; done
        echo "sdb: Tizen Studio sdb not found. Install from https://developer.tizen.org/development/tizen-studio/download" >&2; exit 127
      '';
    });
    devShells = forAllSystems (system: let pkgs = pkgsFor system; isLinux = pkgs.stdenv.hostPlatform.isLinux; sdb-shim = self.packages.${system}.sdb-shim; in {
      default = pkgs.mkShell {
        name = "adb-env";
        packages = with pkgs; [ android-tools scrcpy usbutils libusb1 sdb-shim ] ++ lib.optionals isLinux [ libmtp simple-mtpfs ];
        shellHook = ''
          echo "» adb-env — $(adb --version 2>&1 | head -n1)"
          echo "  adb -s <serial> shell getprop ro.product.model  # verify before reboot"
          echo "  sdb -s <serial> reboot download                  # Tizen Odin mode"
        '';
      };
    });
    formatter = forAllSystems (system: (pkgsFor system).nixfmt);
  };
}
```

## Gotchas

- `pkgs.sdb`, `pkgs.android-udev-rules`, `pkgs.mtpfs` do NOT exist in current nixpkgs — bare reference breaks `nix flake check`. Use `writeShellScriptBin` shim for sdb; udev now via systemd uaccess; use `simple-mtpfs` not `mtpfs`.
- Use `stdenv.hostPlatform.isLinux` not deprecated `stdenv.isLinux`.
- `sdb`/`tizen-studio` not in nixpkgs — `nix search nixpkgs sdb` is empty. Provide shim delegating to `~/tizen-studio/tools/sdb` or `$TIZEN_SDK/tools/sdb`. Keep hermetic `fetchurl` derivation commented until hash pinned via `nix-prefetch-url`.
- Always gate reboots: `adb devices -l` + `adb -s <serial> shell getprop ro.product.model` verify; never bare `adb reboot bootloader` (hits wrong device). Galaxy Watch Active SM-R500 is Tizen — `adb reboot` is wrong; use `sdb -s <serial> reboot download` or hardware Power→3× tap→Download.
- Verify after edit: `nix-instantiate --parse flake.nix && nix flake check --no-build && nix develop --command bash -c 'adb --version; sdb 2>&1 | head'`

## Files

- `flake.nix` + `flake.lock` + `.envrc` (`use flake`) + `.gitignore` (`.direnv/`, `result*`)
