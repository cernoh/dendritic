function zoxide_fzf --description="Pick a zoxide entry via fzf with a 10-box popularity rating and insert it at the cursor"
    # The most-frequently-used directory in the zoxide database gets 10/10
    # boxes; the rest scale proportionally. The preview pane renders the
    # selected directory's structure via `eza --tree` (falls back to `ls`).
    set -l max_score (zoxide query --list --score | awk '{print $1}' | sort -gr | head -1)
    if test -z "$max_score"
        set max_score 0
    end
    set -l entries (zoxide query --list --score | awk -v max="$max_score" '
  BEGIN { filled = "▰"; empty = "-" }
  {
    path = $0
    sub(/^\s*\S+\s+/, "", path)
    rating = (max > 0) ? int($1 / max * 10 + 0.5) : 0
    if (rating > 10) rating = 10
    if (rating < 1 && max > 0) rating = 1
    bar = ""
    for (i = 0; i < rating; i++) bar = bar filled
    for (i = rating; i < 10; i++) bar = bar empty
    printf "%s\t%s\n", bar, path
  }
')
    set -l selection (printf "%s\n" $entries | fzf --height 40% --reverse --no-multi \
  --delimiter '\t' \
  --preview 'eza --tree --level=2 --color=always --group-directories-first --git-ignore {2} 2>/dev/null || ls -la {2}' \
  --preview-window=right:50%:wrap)
    if test -n "$selection"
        # Strip the 10-char bar + tab prefix to recover the bare path.
        set -l path (string sub -s 12 -- "$selection")
        commandline -i -- "$path"
    end
    commandline -f repaint
end