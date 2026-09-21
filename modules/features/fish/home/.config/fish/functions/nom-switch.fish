# Rebuild a dendritic host and watch it through nix-output-monitor (nom).
#
# LIVE-EDITABLE copy from the dendritic checkout (homeless-dotfiles policy
# #93, issue #98). `nom` ships in this feature's home.packages.
#
# Why the shape:
#   - `|&` is load-bearing. nix writes its internal-json log to stderr and
#     nom reads it from there; without the `&` nom sees nothing.
#   - The pipeline ends in nom, so the rebuild's exit status is
#     $pipestatus[1], never $status.
#   - sudo is primed first: its password prompt goes to stderr, which the
#     pipe below captures, so an unprimed prompt would hang invisible.
#   - The `nix run` fallback covers the first switch after this function
#     becomes live, when nom is not yet in PATH.
function nom-switch --description="Rebuild a dendritic host (nixos-rebuild switch) through nix-output-monitor"
    set -l host $argv[1]
    if test -z "$host"
        # fish sets $hostname to the machine name; no external binary needed.
        set host $hostname
    end

    set -l repo "$HOME/.config/dendritic"
    if not test -d "$repo"
        echo "Repository not found: $repo" >&2
        return 1
    end

    sudo -v
    or return 1

    set -l monitor nom
    type -q nom; or set monitor nix run 'nixpkgs#nix-output-monitor' --

    pushd "$repo" >/dev/null
    or return 1

    echo "Switching $host through nom; the build tree renders below." >&2
    sudo nixos-rebuild switch --impure --flake ".#$host" --log-format internal-json -v |& $monitor --json
    set -l switch_status $pipestatus[1]

    popd >/dev/null
    return $switch_status
end
