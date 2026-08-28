function nixpc-switch --description="Rebuild NIXPC (NixOS + embedded Home Manager) from ~/.config/dendritic"
    set -l repo "$HOME/.config/dendritic"
    if not test -d "$repo"
        echo "Repository not found: $repo" >&2
        return 1
    end

    pushd "$repo" >/dev/null
    or return 1

    sudo nixos-rebuild switch --impure --flake .#NIXPC
    set -l switch_status $status
    popd >/dev/null
    return $switch_status
end