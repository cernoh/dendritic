# ~/.config/nushell/env.nu — LIVE-EDITABLE copy from the dendritic checkout
# (homeless-dotfiles policy #93, issue #98). Ported verbatim from
# programs.nushell.extraEnv.

# Editor variables; nvim itself comes from the nvf feature
$env.EDITOR = "nvim"
$env.VISUAL = "nvim"
$env.MANPAGER = "nvim +Man!"

# User-local binaries only — no cross-machine hardcodes
$env.PATH = ($env.PATH | split row (char esep) | prepend [$"($env.HOME)/.local/bin"] | uniq)
