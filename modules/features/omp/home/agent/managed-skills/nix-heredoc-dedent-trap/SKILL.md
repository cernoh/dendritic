---
name: nix-heredoc-dedent-trap
description: "Diagnose and fix NixOS/home-manager builds failing with \"here-document ... delimited by end-of-file (wanted TAG')\": heredoc delimiters inside Nix indented strings emit indented (not column 0) after common-prefix dedent, so the heredoc swallows the rest of the generated activation script."
---

# Nix heredoc dedent trap

NixOS/home-manager activation scripts (and `postBuild` scripts) are often
written as Nix indented strings (`''...''`). Nix strips the common leading
whitespace of all content lines. A heredoc embedded in such a string is only
valid if its **delimiter line ends at column 0 after that dedent** — and a
wrapper's `#!` line must also end at column 0.

If the delimiter line is indented deeper than the string's minimum
indentation, it survives the dedent indented → the shell never sees the
terminator → the heredoc swallows the rest of the script.

## Symptom

`nixos-rebuild switch` / `nix build` of the system fails building
`activation-script.drv` (or the home-manager generation drv) with:

```
activation-script: line NNN: warning: here-document at line MMM delimited by
                   end-of-file (wanted `WRAP_EOF')
activation-script: line NNN: syntax error: unexpected end of file from `if' command
```

The failing drv's builder runs a bash syntax check, so this is a build-time
failure, not a runtime one.

## Diagnosis

1. Find the emitting module: grep the flake for the delimiter name:
   `grep -n '<<WRAP_EOF\|WRAP_EOF' modules/ -r`
2. Confirm the generated text actually has the delimiter indented:
   - NixOS activation entry: `nix eval --impure --raw .#nixosConfigurations.<HOST>.config.system.activationScripts.<name>.text | grep -n 'TAG' | sed -n l`
   - HM entry: `nix eval --impure --raw .#nixosConfigurations.<HOST>.config.home-manager.users.<USER>.home.activation.<name>.data | grep -n 'TAG' | sed -n l`
   (`.data` — HM `home.activation` entries are dag entries; entries can be
   plain strings too, handle both. Pre-fix evidence: delimiter at column 2.)
3. Root cause in source: inside the `''` string, the heredoc body/delimiter
   lines are indented MORE than sibling lines (e.g. body at 18 while the
   string minimum is 16). Compute: Nix strips min-indent (16) → delimiter at 2.

## Fix

Move the heredoc body + delimiter lines to the string's MINIMUM indentation
(flush with the least-indented sibling lines), keeping shell control-flow
lines deeper. After dedent, `#!` and the delimiter land at column 0:

```nix
# min indent of this '' string is 16 spaces
                if [ "$os" = "Linux" ]; then
                  cat > "$dest" <<WRAP_EOF
                #!${pkgs.stdenv.shell}
                exec "${dynamicLinker}" --library-path "${ldpath}" "$bin" "\$@"
                WRAP_EOF
                  chmod +x "$dest"
                fi
```

Delimiter and body may be flush while surrounding shell stays indented —
only the emitted file content matters. Add a short guard comment at the top
of the module noting the constraint so a later reindent does not regress it.

## Verify

1. Re-eval the generated text and confirm `TAG` (and `#!`) start at column 0.
2. Rebuild the exact failing toplevel:
   `nix build '#nixosConfigurations."<HOST>".config.system.build.toplevel' --no-link --impure`
   The drv builders re-run bash syntax checks, so green = syntax valid.
3. Audit sibling heredocs in the same file/repo (`grep -n "<<'\\?[A-Z_]\\+" modules/`)
   — for each, compare delimiter indent against the enclosing `''` string's
   minimum; delimiters at the minimum are safe.

## Notes

- `<<-` (tab-stripping) does NOT save you: it only strips tabs, and Nix dedent
  emits spaces.
- Quoted heredocs (`<<'EOF'`) have the same column-0 delimiter requirement.
- Heredoc CONTENT can be indented arbitrarily in the final file; only the
  delimiter line must be at column 0 (and `#!` must be the file's first bytes).
