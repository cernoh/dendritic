function __fzf_search_args --description="Pick a subcommand/flag for the current commandline via fzf (with descriptions, pre-filled with the partial token) and insert it"
    set -l tokens (commandline)
    if test -z "$tokens"
        commandline -f repaint
        return
    end
    # Ensure a trailing space so complete -C treats it as "complete the next argument"
    set -l query "$tokens"
    if not string match -q -r '\s$' -- "$query"
        set query "$query "
    end
    # complete -C output is tab-separated: completion\tdescription. Preserve both columns.
    set -l candidates (complete -C -- "$query" 2>/dev/null)
    # Fall back to parsing --help for commands without fish completions
    if test -z "$candidates"
        set -l cmd (string match -rg '^\s*(\S+)' -- "$tokens")
        if command -q "$cmd"
            # Capture flag + description when --help output uses "  --flag  description" formatting.
            set candidates (command $cmd --help 2>&1 \
      | string replace -ra '^\s+(-{1,2}[^\s,]+(?:,\s*-{0,2}[^\s,]+)*)\s{2,}(.*?)\s*$' '$1\t$2' \
      | string match -r '.+\t.+')
        end
    end
    # Keep flags and subcommands; drop file/directory paths (anything with /).
    set -l filtered
    for line in $candidates
        set -l token (string match -rg '^([^\t]+)' -- "$line")
        if not string match -q -r / -- "$token"
            set -a filtered "$line"
        end
    end
    set candidates $filtered
    if test -z "$candidates"
        commandline -f repaint
        return
    end
    # Pre-populate fzf's query with the partial token currently being typed.
    # Only extract when there is at least one space in the commandline AND the
    # commandline does not end with whitespace -- i.e. the user is mid-token.
    # This keeps three cases clean:
    #   "cat"     -> no pre-fill (just the command; show everything)
    #   "cat "    -> no pre-fill (cursor is past the space, about to type)
    #   "cat --h" -> pre-fill with "--h" so fzf narrows to matching flags
    set -l fzf_query ""
    if string match -q -r '\s' -- "$tokens" && not string match -q -r '\s$' -- "$tokens"
        set fzf_query (string match -rg '(\S+)\s*$' -- "$tokens")
    end
    set -l selection (printf '%s\n' $candidates | fzf --height 40% --reverse --no-multi \
  --delimiter '\t' --with-nth=1,2 --no-hscroll \
  --header 'Pick an argument' \
  --query "$fzf_query" \
  --preview 'echo {2}' --preview-window=down:1:wrap)
    if test -n "$selection"
        # Tab-separated: take the completion field, then the first alternative.
        set -l clean (string match -rg '^([^\t]+)' -- "$selection")
        set -l clean (string match -rg '^([^,\s]+)' -- "$clean")
        set -l cl (commandline)
        set -l cursor (commandline -C)
        set -l before (string sub -l $cursor -- "$cl")
        set -l token_start (string length -- (string replace -r '\S*$' "" -- "$before"))
        if test $token_start -eq 0
            commandline -i -- " "
            commandline -i -- "$clean"
        else
            set -l prefix (string sub -l $token_start -- "$cl")
            set -l suffix (string sub -s (math "$cursor + 1") -- "$cl")
            commandline -r -- "$prefix$clean$suffix"
            set -l clean_len (string length -- "$clean")
            commandline -C (math "$token_start + $clean_len")
        end
    end
    commandline -f repaint
end