# Rebuild a dendritic host with `nh` instead of `sudo nixos-rebuild`.
#
# nh and dendritic are compatible: nh is a thin wrapper over `nix build` of
# `.#nixosConfigurations.<HOST>.config.system.build.toplevel` plus activation.
# It never looks inside the flake, so the dendritic flake-parts/import-tree
# layout is irrelevant to it. Verified by dry run on 2026-10-08 (ASAHI:
# 7463 -> 7526 paths, 25.7 GiB -> 26.3 GiB).
#
# Why it is not just `nh os switch .#NIXPC`:
#   - `--impure` is MANDATORY here. Every host's first module is
#     `(self.lib.hardwareFromMachine "<system>")` (modules/hosts/AGENTS.md),
#     which imports /etc/nixos/hardware-configuration.nix. Without --impure
#     the eval takes the CI placeholder root filesystem and you "switch" to a
#     system whose root fs is wrong. nh does NOT add --impure for you; the
#     nixos-rebuild aliases in config.fish pass it for the same reason.
#   - the flake is passed as an explicit path, not `.`, so the function works
#     from any cwd even though NH_FLAKE is not set in every fish shell.
#   - the host is checked against modules/hosts/ before the eval starts: a
#     typo otherwise costs a multi-minute evaluation before it fails.
#   - nh itself elevates for the activation step (auto: doas/sudo/run0), so nh
#     runs as the normal user -- which is also correct, because nix then uses
#     the daemon. Never wrap this in `sudo`: nh panics when run as root unless
#     given --bypass-root-check.
#   - nh renders the build through nix-output-monitor automatically when nom is
#     on PATH (this feature's home.packages ships it), same as nom-switch.
function nh-switch --description="Rebuild a dendritic host with nh (defaults to this machine, --impure)"
    set -l repo "$HOME/.config/dendritic"
    if not test -d "$repo"
        echo "Repository not found: $repo" >&2
        return 1
    end

    # No argument = this machine, same default nh itself would pick.
    set -l host $argv[1]
    if test -z "$host"
        set host $hostname
    end

    # Cheap guard against a typo: a real host has a directory in modules/hosts.
    if not test -d "$repo/modules/hosts/$host"
        echo "No such host: $host (not in $repo/modules/hosts)" >&2
        echo "Known hosts:" >&2
        for d in $repo/modules/hosts/*/
            echo "  "(basename $d) >&2
        end
        return 1
    end

    # Anything after the host is passed through, so `nh-switch NIXPC --dry`
    # and `nh-switch NIXPC -- --update` both work. A leading `--` is stripped:
    # nh forwards a literal `--` plus what follows to `nix build` as EXTRA_ARGS,
    # where `--dry` is an unrecognised flag, so passing it through unstripped
    # fails deep in the build instead of at the nh layer.
    set -l rest
    if test (count $argv) -gt 1
        set rest $argv[2..-1]
        if test "$rest[1]" = "--"
            set rest $rest[2..-1]
        end
    end

    # Prime sudo so nh's own activation prompt does not appear mid-build.
    # Skipped for a dry run: --dry/-n never activates anything, so asking for a
    # password would be pure friction (`nh-switch ASAHI --dry` stays unattended).
    if not contains -- --dry $rest; and not contains -- -n $rest
        sudo -v
        or return 1
    end

    pushd "$repo" >/dev/null
    or return 1

    nh os switch --impure --hostname "$host" "$repo#$host" $rest
    set -l switch_status $status

    popd >/dev/null
    return $switch_status
end

# Host names come from the checkout, so a new host needs no edit here.
complete -c nh-switch -f -a "(path basename $HOME/.config/dendritic/modules/hosts/*/)"